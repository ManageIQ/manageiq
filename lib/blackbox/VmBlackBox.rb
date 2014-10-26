$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../util")
$:.push("#{File.dirname(__FILE__)}/../disk")
$:.push("#{File.dirname(__FILE__)}/../fs/MiqFS")
$:.push("#{File.dirname(__FILE__)}/../metadata/VmConfig")

require 'extensions/miq-dir'
require 'zip/zipfilesystem'
require 'ostruct'
require 'yaml'
require 'MiqDisk'
require 'MiqFS'
require 'miq-xml'
require 'xmlStorage'
#require 'mkStorage'
require 'VmConfig'
require 'digest/md5'
include ObjectSpace

module Manageiq
  class BlackBox
    BLACKBOX_NAME = "-MiqBB"
    BLACKBOX_VERSION = 1.0
    GLOBAL_CONFIG_FILE = "/miq.yml"
    FLAT_EXT = "-flat"
    SHADOW_EXT = ".shadow"
    BACKUP_EXT = ".bak"
    RENAMED_EXT = "~"
    DISK_READ_WRITE_ACCESS = "rw"
    MAX_BLACKBOX_SIZE = 1024 * 1024 * 41

    def initialize(vmName, ost=nil)
      @disk = nil
      @fs = nil
      @diskMode = nil
      @config_name = vmName
      @write_data_externally = false
      ost ||= OpenStruct.new

      if ost.miqVm
        @write_data_externally = false
        @vmCfg = ost.miqVm.vm.vmConfig
      elsif ost.skipConfig == true
        @vmCfg = VmConfig.new({})
      else
        @vmCfg = VmConfig.new(@config_name)
      end

      # Load config file methods
      configType = File.extname(@config_name).gsub(".", "").downcase
      unless configType.empty?
        $:.push("#{File.dirname(__FILE__)}")
        require "#{configType}BlackBox"
        extend eval("#{configType.capitalize}BlackBox")

        # Use the first element returned as the bb name
        setBlackBoxName()
      end

      # Get path to local data directory
      if ost.config && ost.config.dataDir
        @localDataDir = File.join(ost.config.dataDir, Digest::MD5.hexdigest(@config_name))
      elsif $miqHostCfg && $miqHostCfg.dataDir
        @localDataDir = File.join($miqHostCfg.dataDir, Digest::MD5.hexdigest(@config_name))
      else
        @localDataDir = "/tmp"
      end

      # Determine if we are writing data to blackbox or local data directory
      @write_data_externally = !@bbExists

      # For now we are always writing externally
      @write_data_externally = true

      loadGlobalSettings()

      @xmlData = loadXmlConfig()

      #openMkDb

      removeTempFiles()
      # Make sure the file handle is closed when the object is garbage collected
      # incase it is left open by the caller.
      #define_finalizer(@disk, lambda {|d| d.close if d;})
    end

    def self.vmId(vmName)
      bb = Manageiq::BlackBox.new(vmName)
      bb.close
      return bb.vmId
    end

    def close
      #closeMkDb
      closeFsHandle
      removeTempFiles()
    end

    def create(new_hash={})
      new_hash = {:options=>{:config_locally=>false},
        :config=>{}
      }.merge(new_hash)

      ret = {:results=>{:error=>false}}
      created = false
      unless self.exist?
        createBlackBox
        created = true
        # Since we just created the blackbox we need to reset global config
        # object before calling validate so will not find matching guids.
        loadGlobalSettings()
      end
      updateConfigFile() if new_hash[:options][:config_locally]==true && !self.configured?

      ret.merge!(validate(new_hash))

      # Do the delete after the creation of the blackbox, because we may
      # want to move the existing data from the temp folder into the blackbox.
      deleteLocalDataDir(:forceDelete=>true) if created

      ret[:results][:created] = created
      return ret
    end

    def updateConfigFile()
      updateCfgFile()
      @vmCfg = VmConfig.new(@config_name)
    end

    def exist?
      @bbExists
    end

    def configured?
      return false if @bbName.nil?

      # Loop through the list of disk and see if the Blackbox disk file is included.
      bbBaseName = File.basename(@bbName)
      config = @vmCfg.getDiskFileHash.inject(false) do |m,k|
        break true if k[1].downcase.include?(bbBaseName.downcase)
        m
      end
      return config
    end

    def shadowed?
      @usingShadow
    end

    def usingExternalDataStore?
      @write_data_externally
    end

    def delete(new_hash={})
      new_hash = {:options=>{:config_locally=>false},
        :config=>{:vmId=>@cfg[:vmId]}
      }.merge(new_hash)

      ret = {:results=>{:error=>false}}
      if new_hash[:options][:config_locally]==true
        deleteFromCfgFile if self.configured?
        deleteBlackBox if self.exist?
      end

      # Merge the results of the validate code
      ret.merge!(validate(new_hash, false))

      # Do the delete after the creation of the blackbox, because we may
      # want to move the existing data from the temp folder into the blackbox.
      deleteLocalDataDir(:forceDelete=>true)

      return ret
    end

    def vmId=(uuid)
      saveGlobalValue(:vmId, uuid)
    end

    def vmId
      @cfg[:vmId]
    end

    def smart=(flag)
      if flag == false
        deleteFromCfgFile if self.configured?
      else
        create()
      end
      saveGlobalValue(:smart, flag)
    end

    def smart
      @cfg[:smart]
    end

    def validate(settings, check_vmId = true)
      config = settings[:config]

      # If we are deleteing the Vm we do not need to perform this check
      if check_vmId
        raise "VmBlackBox.validate: Configuration  must have a vmId." if config[:vmId].nil?

        if config[:vmId] != @cfg[:vmId]
          # Move the current values into the history
          history = Hash.new.merge(@cfg)
          history.delete(:history)
          history[:hist_created] = Time.now.utc

          @cfg[:history] ||= []
          @cfg[:history] << history

          # Store the new values
          @cfg.merge!(config)
          @cfg[:vmUuid] = self.getVmUuid if self.respond_to?(:getVmUuid)

          saveGlobalSettings
        end
      end

      return {:results=>{:created=>false, :exists=>self.exist?, :configured=>self.configured?, :bbName=>@bbName, :vmName=>@config_name},
              :config=>@cfg}
    end

    def writeData(filename, data, fs=nil)
      unless @write_data_externally

        # If the blackbox does not exist yet, create it but do not associate with the config file.
        createBlackBox() unless self.exist?

        # If the current blackbox is writable just continue on
        unless writeable?()
          # If the blackbox is not writable we either create a shadow copy to write to
          # or skip writing the data if the target location is read-only
          if isConfigPathWritable?() == true
            makeDiskWriteable()
          else
            return
          end
        end

        dk, fs = getFsHandle(DISK_READ_WRITE_ACCESS)

        # Update stats in base config file
        @cfg[:updated_on] = Time.now.utc
        @cfg[:created_on] = Time.now.utc  unless @cfg[:created_on]
        @cfg[:version] = BLACKBOX_VERSION unless @cfg[:version]

        # Write the data
        writeDataInternal(filename, data, fs)

        saveGlobalSettings(fs) unless filename == GLOBAL_CONFIG_FILE

        closeFsHandle
        mergeShadowDisk if shadowed?
      else
        Dir.mkdir(@localDataDir, 755) unless File.exist?(@localDataDir)
#       fullpath = File.join(@localDataDir, File.basename(filename))
        filename2 = filename.gsub("/", "_")
        fullpath = File.join(@localDataDir, filename2)
        f = File.open(fullpath, "w")
        f.write(data.to_s)
        f.close
      end
    end

    def makeDiskWriteable()
      # Rename the disk file and copy it to a new file for writing
      # We name need to use the createShodown method on windows if we hit
      # the same issue since a rename is likely to fail in that case.
      renameDiskFiles()
      #createShadow()
    end

    def renameDiskFiles()
      closeFsHandle()
      require 'fileutils'

      begin
        getBlackboxNameArray().each do |d|
          tempBBName = d + RENAMED_EXT
          File.rename(d, tempBBName)
          FileUtils.copy(tempBBName, d)
        end
      rescue => err
        $log.error  "Blackbox rename failed. [#{err}]" if $log
        $log.debug  err.backtrace.join("\n") if $log
      end
    end

    # This method can be over-written by the extended class for the VM config type
    # Otherwise we just return the blackbox disk name as an array
    def getBlackboxNameArray()
        getActiveBlackBoxName.to_a
    end

    def removeTempFiles()
      mergeShadowDisk if shadowed?
      # Try to remove the backup file
      begin
        getBlackboxNameArray().each do |d|
          tempBBName = d + RENAMED_EXT
          File.delete(tempBBName) if File.exist?(tempBBName)
        end
      rescue
        # Its ok if it fails
      end
    end

    def readData(filename)
      unless @write_data_externally
        mergeShadowDisk if shadowed?
        dk, fs = getFsHandle()
        ret = fs.fileOpen(filename).read
      else
        #fullpath = File.join(@localDataDir, File.basename(filename))
        filename2 = filename.gsub("/", "_")
        fullpath = File.join(@localDataDir, filename2)
        ret = File.read(fullpath)
      end
      return ret
    end

    def self.isBlackBox(filename)
      filename.include?(BLACKBOX_NAME)
    end

    def self.isBlackBox?(disk)
        begin
            return false if File.size(disk.dInfo.fileName) > MAX_BLACKBOX_SIZE
            fs = MiqFS.getFS(disk.getPartitions[0], "Fat32Probe")
            return false if fs.nil?
            return true  if fs.fileOpen(GLOBAL_CONFIG_FILE).read
        rescue
            # Ignore errors and return false
        end
        return false
    end

    def writeable?
      begin
        dk, fs = getFsHandle(DISK_READ_WRITE_ACCESS)
        closeFsHandle
        ret = true
      rescue => err
        $log.warn  "Blackbox locked for writing. [#{err}]" if $log
        $log.debug  err.backtrace.join("\n") if $log
        ret = false
      end
      ret
    end

    # This method is used to cleanup local storage data after it is sent to the server.
    def postSync(options = {})
      deleteLocalDataDir(options)
    end

    ###################
    # Private methods #
    ###################
    private
    def isConfigPathWritable?()
      return @configPathWritable unless @configPathWritable.nil?

      # Determine if the config file is in a writable location
      @configPathWritable = false

      # Create an 8.3 file to test with
      testFile = File.dirname(@config_name) + "/#{Time.now.to_i.to_s[0..7]}.miq"
      begin
        # Try to write a test file here, if it does not throw an error we are ok
        File.open(testFile,"w") {|f|}
        @configPathWritable = true
      rescue => e
        @configPathWritable = false
      ensure
        File.delete(testFile) if File.exists?(testFile)
      end
      return @configPathWritable
    end

    def writeDataInternal(filename, data, fs)
      # Make sure the requested directory exists then write the data
      createDirectory(File.dirname(filename), fs)
      fo = fs.fileOpen(filename, "w"); fo.write(data.to_s); fo.close
    end

    def createDirectory(path, fs)
      dirPath = "/"
      path.split("/").each {|d|
        dirPath = File.join(dirPath, d) unless d.empty?
        fs.dirMkdir(dirPath) unless fs.fileDirectory?(dirPath)
      }
    end

    def loadGlobalSettings()
      begin
        @cfg = {:smart=>false}
        @cfg.merge!(YAML.load(readData(GLOBAL_CONFIG_FILE)))
      rescue
      end
    end

    def saveGlobalValue(key, value)
      @cfg[key] = value
      saveGlobalSettings
    end

    def saveGlobalSettings(fs=nil)
      x = ""
      YAML.dump(@cfg, x)
      if fs
        writeDataInternal(GLOBAL_CONFIG_FILE, x, fs)
      else
        writeData(GLOBAL_CONFIG_FILE, x)
      end
    end

    def mergeShadowDisk
      return false unless shadowed?

      srcDisk, srcDescript = getActiveBlackBoxName
      destDisk, destDescript = getBaseBlackBoxName

      begin
        File.delete(destDisk)
        File.rename(srcDisk, destDisk)
        File.delete(srcDescript) unless srcDisk == srcDescript
        setBlackBoxName
        return true
      rescue
        return false
      end
    end

    def setBlackBoxName
      @bbName = getActiveBlackBoxName
      @bbExists = !@bbName.nil?
      return @bbName
    end

    def getActiveBlackBoxName
      @usingShadow = false
      @usingBase = false

      shadowDisk = getShadowBlackBoxName
      if File.exist?(shadowDisk)
        @usingShadow = true
        return shadowDisk
      end

      baseDisk = getBaseBlackBoxName
      if File.exist?(baseDisk)
        @usingBase = true
        return baseDisk
            end

      # Since we didn't get any expected disks, we probe the disk files
      allDisks = @vmCfg.getDiskFileHash
      foundDisk = probeDisks(allDisks)
      return foundDisk unless foundDisk.nil?

      return nil
    end

    def getShadowBlackBoxName
      diskName = getBaseBlackBoxName
      diskName.insert(diskName.index(".") || -1, SHADOW_EXT)
    end

    def createShadow
      disks = getBaseBlackBoxName
      shadowDisks = getShadowBlackBoxName
      require 'fileutils'
      disks.each {|p|
        shadowName = shadowDisks.shift
        FileUtils.copy(p, shadowName) unless File.exist?(shadowName)
      }

      shadowDisk = getShadowBlackBoxName
      setBlackBoxName()
      postDiskCopy(shadowDisk) if self.respond_to?(:postDiskCopy)
    end

    def getBackupBlackBoxName
      backupDisks = getBaseBlackBoxName
      backupDisks.each {|d| d.insert(-1, BACKUP_EXT) }
    end

    def probeDisks(disks)
      disks.each_value do |v|
        begin
          # Make sure the disk size is within our blackbox range and
          # does not end with a temporary file marker.
          if File.size(v) <= MAX_BLACKBOX_SIZE && v[-1,1]!=RENAMED_EXT
            d = OpenStruct.new({:fileName=>v})
            disk = MiqDisk.getDisk(d)
            fs = MiqFS.getFS(disk.getPartitions[0])
            cfg = fs.fileOpen(GLOBAL_CONFIG_FILE).read
            return v if cfg
          end
        rescue
          # Ignore any errors and just move on the next disk
        ensure
          disk.close if disk
        end
      end

      return nil
    end

    def getFsHandle(mode="r")
      if mode === @diskMode
        return @disk, @fs if @disk && @fs
      end

      closeFsHandle()

      di = OpenStruct.new({:fileName=>@bbName, :mountMode=>mode})
      @disk = MiqDisk.getDisk(di)
      @fs = MiqFS.getFS(@disk.getPartitions[0])
      @diskMode = mode
      return @disk, @fs
    end

    def closeFsHandle()
      # Close current disk handles
      if @disk
        @disk.close
        @disk = nil
        @fs = nil
        @diskMode = nil
      end
    end

    def createBlackBox
      $log.info "Creating Blackbox started for [#{@config_name}]." if $log
      start_time = Time.now

      unzipDisks()
      copyDiskFiles(getBaseBlackBoxName)
      setBlackBoxName()

      getActiveBlackBoxName()
      postDiskCopy() if self.respond_to?(:postDiskCopy)
      $log.info "Creating Blackbox completed successfully for [#{@config_name}] in [#{Time.now - start_time}] seconds." if $log
    end

    def deleteBlackBox
      begin
        mergeShadowDisk if self.shadowed?

        closeFsHandle

        getBlackboxNameArray().each do |d|
          File.delete(d) if File.exist?(d)
        end

        #clear all config settings
        setBlackBoxName
        @cfg = {:smart=>false}

        return true
      rescue => err
        return false
      end
    end

    def copyDiskFiles(path)
      # Miq BlackBox disks are compressed under the miqhost/data directory.
      dataDir = File.expand_path("#{File.dirname(__FILE__)}/../../host/miqhost/data")
      extractFiles = getExtractFiles

      require 'fileutils'
      extractFiles.each do |f|
        src = File.join(dataDir, f)
        dest = get_destination_path(path, f)
        Dir.mkpath(File.dirname(dest))
        FileUtils.copy(src, dest)
        $log.debug "Disk file copied from [#{src}] to [#{dest}]" if $log
      end

      @write_data_externally = false
    end

    def get_destination_path(name, mask)
      dir, dfBase, ext = File.splitpath(name)
      dfBase.sub!(Manageiq::BlackBox::BLACKBOX_NAME, "-" + mask)
      return File.normalize(File.join(dir, dfBase))
    end


    def unzipDisks
      # Miq BlackBox disks are compressed under the miqhost/data directory.
      dataDir = File.expand_path("#{File.dirname(__FILE__)}/../../host/miqhost/data")
      extractFiles = getExtractFiles

      extract = false
      extractFiles.each {|f|
        outputFile = File.join(dataDir, f)
        extract = true unless File.exist?(outputFile)
      }

      # If the disk files already exist we are done here.
      return unless extract

      #Open zipfile and get a handle
      zipFile = File.join(dataDir, "miqbb100.zip")
      Zip::ZipFile.open(zipFile) {|z|
        # Process each file we want out of the zipfile
        extractFiles.each {|i|
          outputFile = File.join(dataDir, i)
          File.open(outputFile, "wb") { |f| f.write(z.file.read(i)) }
        }
      }
    end

    def doesBBFileExist?(filename)
      # If the blackbox has not been created the file cannot exist
      return false unless self.exist?
      return false if @fs.nil?

      # Return the results of fileExists
      @fs.fileExists?(filename)
    end

    def deleteLocalDataDir(options={})
      if @write_data_externally || options[:forceDelete]
        if File.exist?(@localDataDir)
          Dir.foreach(@localDataDir) {|f| File.delete(File.join(@localDataDir,f)) unless f[0..0] === "."}
          Dir.delete(@localDataDir)
        end
      end
        end
  end
end

# Only run if we are calling this script directly
#if __FILE__ == $0 || File.basename($0, "*.") == "rdebug-ide" then
if __FILE__ == $0
  def test1
    st = Time.now

    require 'miq-logger'
    $log = MIQLogger.get_log(nil, __FILE__)
    #   $log.level = Log4r::INFO

    #   vmId = Manageiq::BlackBox.vmId(vmName)
    #   p "vmId =      [#{vmId}]"

    vmName = "\\\\dev008\\vms\\Win2K3-EE\\Windows Server 2003 Enterprise Edition.vmx"
    bb = Manageiq::BlackBox.new(vmName)

    #p "Validate    [#{bb.validate({:vmId=>72947, :svrId=>789210112, :path=>"C:/test"})}]"
    #   bb.updateCfgFile
    #   bb.deleteFromCfgFile

    #   names = "D:/temp/XML diff/accounts.xml"
    #   names = "D:/temp/XML diff/accounts2.xml"
    #   xfer = REXML::Document.new(File.open(names))
    #   bb.saveXmlData(xfer, "accounts")

    #   bb.vmId = "ffffffff-ffff-11dc-956e-0018de832874"
    #   bb.delete({:options=>{:config_locally=>true}, :config=>{}})

    p "Exist?      [#{bb.exist?}]"
    p "Configured? [#{bb.configured?}]"
    p "Writeable?  [#{bb.writeable?}]"
    p "Shadowed?   [#{bb.shadowed?}]"
    p "Using External Datastore?   [#{bb.usingExternalDataStore?}]"
    p "vmId =      [#{bb.vmId}]"

    #bb.create({:options=>{:config_locally=>true}, :config=>{:vmId=>"12345"}})
    bb.vmId = "ffffffff-ffff-11dc-956e-0018de832874"
    p "Exist?      [#{bb.exist?}]"
    p "Writeable?  [#{bb.writeable?}]"
    p "Shadowed?   [#{bb.shadowed?}]"
    p "vmId =      [#{bb.vmId}]"
    p "Using External Datastore?   [#{bb.usingExternalDataStore?}]"
    #   bb.recordEvent( {"timestamp"=>Time.now, "status"=>"ok", "event_type"=>"Test", "message"=>"testing", "hostId"=>"ffffffff-ffff-11dc-956e-0018de832874", "table_name"=>"vm_operation_events", } )

    bb.dumpEvents

    #   bb.testFind(nil, nil)
    #   bb.testFind(nil,{"timestamp"=>"1194468706"})
    #   bb.testFind(nil,{"timestamp"=>"1194468705"})
    #   bb.testFind({"timestamp"=>"1194464369"},nil)
    #   bb.testFind({"timestamp"=>"1194464369"},{"timestamp"=>"1194468706"})
    #   bb.testFind({"timestamp"=>"1194464369"},{"timestamp"=>"1194468705"})
    bb.close
    p "done #{Time.now-st}"
  end

  test1
  puts "done"
end
