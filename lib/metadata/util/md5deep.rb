$:.push("#{File.dirname(__FILE__)}/win32")
$:.push("#{File.dirname(__FILE__)}/../../util")

require 'rubygems'
require 'time'
require 'peheader'
require 'versioninfo'
require 'miq-xml'
require 'ostruct'
require 'miq-encode'

class MD5deep
  attr_reader   :fullDirCount, :fullFileCount
  attr_accessor :versioninfo, :imports

  def initialize(fs=nil, options = {})
    @fullFileCount = 0
    @fullDirCount = 0
    #Create XML document
    @xml = XmlHash.createDoc(:filesystem)
    @fs = fs if fs.kind_of?(MiqFS)

    # Read optional parameters if they exist in the options hash
    @opts = {'versioninfo'=>true,'imports'=>true, 'contents'=>false,
      'exclude'=>["pagefile.sys","hiberfil.sys", ".", ".."],
      'digest'=>["md5"], "winVerList"=>%w{.exe .dll .ocx .scr}
    }.merge(options)
    # Make sure md5 is part of our digest array
    @opts['digest'].push("md5") unless @opts['digest'].include?("md5")
    # Convert hash to an OpenStruct for cleaner referencing
    @opts = OpenStruct.new(@opts)
    
    # Conditionally load digest libraries as needed.
 	  @opts.digest.each do |h|
 	    begin
 	      require 'digest/' + h.downcase
 	    rescue LoadError
 	      # This load error is not a concern since the standard digests are already included
 	      # in ruby by default, and the non-standard ones will be loaded by their name above.
 	      #$log.debug "Unable to load module for [#{h}]"
 	    end
 	  end
  end

  def scan(path, rootID = "/")
    path = File.expand_path(path)
    rootID = rootID[2..-1] if (rootID.length > 2 && rootID[1..1] == ":")
    xmlNode = @xml.root.add_element("dir", "name"=>rootID)
    read_fs(path, xmlNode)
    return @xml
  end

  def self.scan_glob(fs, filename, options = {})
    md5 = MD5deep.new(fs, options)
    xml = md5.scan_glob(filename)
  end

  def scan_glob(filename)
    filename.gsub!("\\","/")
    startDir = File.dirname(filename)
    globPattern = File.basename(filename)
    @xml.root.add_attribute("base_path", startDir)
    @fs.chdir(startDir)

    # First check if we are passed a fully qualifed file name
    if @fs.fileExists?(filename)
      processFile(startDir, globPattern, @xml.root)
    else
      # If the file is not found then process the data as a glob pattern.
      @fs.dirGlob(globPattern) do |f|
        #$log.info "Glob file found: [#{f}]"
        # Passing "startDir" as the first parameter is a work-around for issues
        # when scanning Win VMs from Linux where the path returned from dirGlob
        # do not include the drive letter.
        # Below is the original line
        #processFile(File.dirname(f), File.basename(f), @xml.root)
        processFile(startDir, File.basename(f), @xml.root)
      end
    end
    return @xml
  end

  def read_fs(path, xmlNode)
    statHash = Hash.new

    if @fs then
      @fs.dirForeach(path)  { |x| processFile(path, x, xmlNode) }
      @fs.dirForeach(path)  { |x| processDir(path,  x, xmlNode) }
    else
      Dir.foreach(path)     { |x| processFile(path, x, xmlNode) }
      Dir.foreach(path)     { |x| processDir(path,  x, xmlNode) }
    end

    # Add up all the sums for all sub-elements
    xmlNode.add_attributes(calculate_sums(xmlNode))
  end

  def processDir(path, x, xmlNode)
    if x !="." && x!=".." then
      currFile = File.join(path, x)

      begin
        if File.directory?(currFile) then
          @fullDirCount += 1
          #$log.debug "DIR : #{currFile}"
          xmlSubNode = xmlNode.add_element("dir", "name"=>x, "fqname"=>currFile)
          xmlSubNode.add_attributes({"atime"=>File.atime(currFile).getutc.iso8601, "ctime"=>File.ctime(currFile).getutc.iso8601, "mtime"=>File.mtime(currFile).getutc.iso8601})
          read_fs(currFile, xmlSubNode)
        end
      rescue Errno::EACCES, RuntimeError
      end
    else
      @fullDirCount += 1
    end
  end


  def processFile(path, x, xmlNode)
    if (@opts.exclude.include?(x) == false) && x[0..0] != "$" then
      currFile = File.join(path, x)

      begin
        #       unless File.directory?(currFile) then
        unless isDir?(currFile) then
          # File we have an exclusion list and the current file is in it, skip to the next file
          @fullFileCount += 1
          fh = fileOpen(currFile)

          xmlFileNode = xmlNode.add_element("file", "name"=>x, "fqname"=>currFile)
          statHash = Hash.new
          statHash.merge!(getFileStats(fh))
          statHash.merge!(calculate_digest(fh))
          xmlFileNode.add_attributes(statHash)

          ext = File.extname(currFile).downcase
          if @opts.winVerList.include?(ext) then
            if @opts.versioninfo || @opts.imports
              peHdr = PEheader.new(fh) rescue nil
              unless peHdr.nil?
                xmlFileNode.add_element("versioninfo", peHdr.versioninfo) if @opts.versioninfo && !peHdr.versioninfo.blank?
                xmlFileNode.add_element("libraries", "imports" => peHdr.getImportList) if @opts.imports && !peHdr.imports.blank?
              end
            end
          end

          getFileContents(fh, xmlFileNode) if @opts.contents == true
          fh.close
        end
      rescue Errno::EACCES, RuntimeError, SystemCallError
        fh.close if fh.is_a?(File) && !fh.closed?
      end
    else
#      @fullDirCount += 1
    end
  end

  def isDir?(currFile)
    if @fs then
      @fs.fileDirectory?(currFile)
    else
      File.directory?(currFile)
    end
  end

  def fileOpen(currFile)
    if @fs then
      fh = @fs.fileOpen(currFile)
    else
      fh = File.open(currFile)
    end
  end

  def getFileStats(fh)
    # If we are processing a member of the File class, use the File::Stat object to get data
    fh = fh.stat if fh.class == File
    {"size"=>fh.size, "atime"=>fh.atime.getutc.iso8601, "ctime"=>fh.ctime.getutc.iso8601, "mtime"=>fh.mtime.getutc.iso8601}
  end

  def calculate_sums(xmlNode)
    rollup = create_digest_hash
    # Add size to the hash as a Fixnum
    rollup['size'] = 0

    xmlNode.each_element do |e|
      rollup.each_pair do |k,v|
        if k == "size" then
          rollup[k] += e.attributes[k].to_i if e.attributes[k]
        else
          rollup[k] << e.attributes[k] if e.attributes[k]
        end
      end
    end

    rollup.each {|k,v| rollup[k] = v.to_s unless k == 'size'}
    return rollup
  end

  def calculate_digest(fileName)
    unless @opts.digest.empty? then
#      if fileName.class.to_s != "MiqFile"
#        raise "File [#{fileName}] is not in a readable state." unless File.readable?(fileName)
#      end

      # Create hash for requested digests
      digest = create_digest_hash

      fileName.seek(0, IO::SEEK_SET)
      # Loop over each digest and add the file contents
      while buf = fileName.read(10240000)
        digest.each_pair {|k,v| v << buf}
      end
    end

    digest.each_pair {|k,v| digest[k] = v.to_s}
    return digest
  end

  def create_digest_hash
    dHash = Hash.new
 	  @opts.digest.each do |h|
 	    begin
 	      dHash[h.downcase] = eval("Digest::" + h.upcase).new
 	    rescue NameError
 	      # If we are unable to load a digest, skip it.
 	    end
 	  end
 	  return dHash
  end

  def getFileContents(fh, xml_node)
    fh.seek(0, IO::SEEK_SET)
    buf = fh.read(1024000)
    xml_node.add_element("contents", "compressed"=>"true", "encoded"=>"true").text = (MIQEncode.encode(buf))
  end

  def to_xml
    @xml
  end
end


# Only run if we are calling this script directly
if __FILE__ == $0 then
#if 1
  $:.push("#{File.dirname(__FILE__)}/../../MiqVm")
  require 'MiqVm'
  require 'miq-logger'

  $log = MIQLogger.get_log(nil, __FILE__)
  $log.level = Log4r::INFO

  startTime = Time.now

  # Mount VM Image to a real drive letter
#  mountNative, startPath = false, "M:/WINDOWS/system32/mui"
  startPath = "c:/windows/system32"
  vmHDImage = "D:\\Virtual Machines\\VC20\\Windows Server 2003 Standard Edition.vmx"

  begin
    @vm = MiqVm.new(vmHDImage, nil)

    @systemFs = @vm.vmRootTrees[0]
    if @systemFs
      #Note: SHA22 is not valid.  It is here for testing of bad parms
      #md5 = MD5deep.new(@systemFs, {"digest"=>%w(SHA1)}) #, %w(MD5 RMD160 SHA1 SHA256 SHA384 SHA512 SHA22))
      md5 = MD5deep.new(@systemFs) #, %w(MD5 RMD160 SHA1 SHA256 SHA384 SHA512 SHA22))
      #xml = md5.scan("C:/Program Files/VMware/VMware VirtualCenter 2.0")
      xml = md5.scan_glob("c:/windows/system32/*.sc?")
#      xml = md5.scan_glob("C:/Program Files/vmware/VMware VirtualCenter 2.0/vmprep.exe")

      $log.info "writing XML..."
      xml.write(STDOUT,0)
      puts ""
      File.open("d:/temp/md5out.xml", "w") {|f| xml.write(f, 0); f.close}
      stopTime = Time.now
    end

    $log.info startTime
    $log.info stopTime
    $log.info "Run  time : #{(stopTime-startTime).to_i}"
    $log.info "File count: #{md5.fullFileCount}"
    $log.info "Dir  count: #{md5.fullDirCount}"
  rescue NameError=> err
    unless err.to_s.include?("MiqVm")
      $log.warn err
      $log.fatal err.backtrace.join("\n")
    end
  rescue => err
    $log.fatal err
    $log.fatal err.backtrace.join("\n")
  end
end
