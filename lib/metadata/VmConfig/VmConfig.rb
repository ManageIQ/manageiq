$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../../util")
$:.push("#{File.dirname(__FILE__)}/../../disk/modules")
$:.push("#{File.dirname(__FILE__)}/../VMMount")
$:.push("#{File.dirname(__FILE__)}/../../VMwareWebService")

require 'pathname2'
require 'VMMount'
require 'miq-unicode'
require 'miq-xml'
require 'MiqVimInventory'
require 'timeout'
require 'miq-extensions'
require 'MiqVimBroker'

class VmConfig

	attr_reader :configFile

	def initialize(filename)
		@configFile = nil
		@configPath = nil
    @direct_file_access = true

		if filename.kind_of? Hash
      @direct_file_access = false
      @cfgHash = filename
    else
      @cfgHash = Hash.new
      # If filename contains embedded new-line chars treat it as data.  Otherwise, its a filename.
      if filename.index("\n")
        f = filename
      else
        #raise "Cannot open config file: [#{filename}]" if not File.file?(filename)
        set_vmconfig_path(filename)

        configType = File.extname(filename).gsub(".", "").downcase
        require configType + "Config"
        extend Kernel.const_get(configType.capitalize + "Config")
        f = convert(filename)
      end

      process_file(f)

      f.close if f.class == File

      postProcessDisks()
		end

    # Handle oddities
    configuration_fixup()
	end

  def process_file(data_lines)
    data_lines.each_line do |line|
      line.AsciiToUtf8!.strip!
      next if line.length == 0
      next if line =~ /^#.*$/
      next if !line.include?("=")
      k, v = line.split(/\s*=\s*/)

      #Note: All key names are lower-cased for easy lookup
      k = k.downcase
      v = v.gsub(/^"/,"").gsub(/"$/,"")

      @cfgHash[k] = v
    end
  end

  def postProcessDisks()
		#Convert absolute paths to relative paths for the disks
		if @direct_file_access
			getAllDiskKeys.each do |dk|
				next if @cfgHash[dk + ".devicetype"] && @cfgHash[dk + ".devicetype"].include?("cdrom")
				next if @cfgHash[dk + ".filename"] && @cfgHash[dk + ".filename"].downcase == "auto detect"

        begin
          dskPath = Pathname2.new(@cfgHash[dk + ".filename"])
          begin
            @cfgHash[dk + ".filename"] = dskPath.relative_path_from(Pathname2.new(@configPath)).to_s.tr("\\", "/") if dskPath.absolute?
          rescue
            @cfgHash[dk + ".filename"] = dskPath.to_s.tr("\\", "/")
          end
          if self.respond_to?(:diskCreateType)
            createType = diskCreateType(@cfgHash[dk + ".filename"])
            @cfgHash[dk + ".createType"] = createType if createType
          end
          if self.respond_to?(:diskControllerType)
            adapterType = diskControllerType(@cfgHash[dk + ".filename"])
            @cfgHash[dk + ".adapterType"] = adapterType if adapterType
          end
        rescue => err
          $log.warn "VmConfig: Failed to convert path: #{@cfgHash[dk + ".filename"]}, #{err}"
        end
			end
		end
  end

	def getHash
		@cfgHash
	end

	def getDiskFileHash
		return @diskFileHash if @diskFileHash

		@diskFileHash = Hash.new
		getAllDiskKeys.each do |dk|
			next if @cfgHash[dk + ".devicetype"] && @cfgHash[dk + ".devicetype"].include?("cdrom")
			next if @cfgHash[dk + ".filename"] && @cfgHash[dk + ".filename"].downcase == "auto detect"
      filename = @cfgHash[dk + ".filename"]
      @diskFileHash[dk] = filename
			if @direct_file_access
        ds, dir, name = split_filename(filename)
        if ds.nil? && !Pathname2.new(filename).absolute?
          @diskFileHash[dk] = File.expand_path(File.join(@configPath, filename))
        end
      end
		end
		return @diskFileHash
	end # getDiskFileHash

	def getAllDiskKeys
		dskKeys = @cfgHash.keys.delete_if { |e| !diskKey?(e) }.collect! { |e| e.gsub(".filename", "")}
		dskKeys.delete_if { |dk| @cfgHash[dk + ".present"].to_s.downcase == "false" }
		return dskKeys.sort
	end

	def getSnapshotDiskFileHash
		return @snapshotdiskFileHash if @snapshotdiskFileHash

    #For snapshots we need to keep the disks order by snapshot uid, then by device
		@snapshotdiskFileHash = Hash.new {|h,k| h[k]={}}
		getSnapshotDiskKeys.each do |dk|
			next if @cfgHash[dk + ".devicetype"].to_s.include?("cdrom")
			next if @cfgHash[dk + ".filename"].to_s.downcase == "auto detect"
      dk =~ /^snapshot\d+/
      sn_uid = @cfgHash["#{$&}.uid"]
      key = @cfgHash[dk + ".node"]

      # Independent disks do not par-take in snapshots.  Check the mode of the parent disk.
      next if @cfgHash["#{key}.mode"].to_s.include?('independent')

      @snapshotdiskFileHash[sn_uid]['disks'] ||= {}
      filename = @cfgHash[dk + ".filename"]
      disk_path = filename

      if @direct_file_access
        ds, dir, name = split_filename(filename)
				if ds.nil? && !Pathname2.new(@cfgHash[dk + ".filename"]).absolute?
					disk_path = File.join(@configPath, filename)
				end
      end
      @snapshotdiskFileHash[sn_uid]['disks'][key] = disk_path
		end
		return @snapshotdiskFileHash
	end # getSnapshotDiskFileHash

	def getSnapshotDiskKeys
		dskKeys = @cfgHash.keys.delete_if { |e| !snapshotdiskKey?(e) }.collect! { |e| e.gsub(".filename", "")}
		dskKeys.delete_if { |dk| @cfgHash[dk + ".present"].to_s.downcase == "false" }
		return dskKeys.sort
	end

  def set_vmconfig_path(config_path)
    ds, dir, name = split_filename(config_path)
    @configFile = ds.nil? ? File.normalize(config_path) : config_path
    @configPath = File.dirname(@configFile)
  end

	def to_xml(diskStats=true, miqvm=nil)
    # If loaded directly from a hash object, try to add snapshot metadata before processing
    load_vim_snapshots(miqvm)

    set_vmconfig_path(miqvm.vmConfigFile) unless miqvm.nil?

    normalize_file_paths()

    xml = MiqXml.createDoc("<vm_configuration><hardware></hardware><vm/></vm_configuration>", {"vendor" => self.vendor})
    #Sort the Hash into an array to group like keys and add each array to the XML doc
    @cfgHash.sort {|a,b| a<=>b}.each do |(k,v)|
      next if k[0..0] == '.'
      insert_XML(k, v, xml)
    end

    # Pre-load data
    unless miqvm.nil?
      # Make sure we have the volume manager and loaded
      begin
        miqvm.vmRootTrees[0]
        @vol_mgr_loaded = true
      rescue LoadError
        $log.warn "add_disk_stats [#{$!.class}]-[#{$!}]"
      end

      files(miqvm)
    end

    # Add virtual disk sizes
    add_disk_stats(xml, miqvm) if diskStats

    # Here we list all files in the directory and get their size on disk.
    add_file_sizes(xml, miqvm)

    # Add partition and volume information
    add_volumes(xml, miqvm)

    # Add date and size info for snapshots
    add_snapshot_size(xml, miqvm)

    #TODO: Re-enable
    #normalize_path_names(xml)

		return xml
	end

  alias :toXML :to_xml

	def getDriveImageList
		vmDisks = Array.new()
		# Convert config file to XML
		xml = self.toXML(false)
		# Find the disk section of the XML
		xml.root.each_recursive do |e|
			controller_type = e.attributes["type"] if e.name == "controller"
			# Only process drives that are present and have a filename
			if (e.attributes['present']!=nil && e.attributes['present'].downcase == 'true') && e.attributes['filename']!=nil && (e.attributes['type']!=nil && e.attributes['type'].downcase == 'disk') && (e.attributes['id']!=nil && e.attributes['id'].include?(":")) then
				# Make sure the disk we are looking at is not a CD-ROM
				if e.attributes['devicetype']==nil || (e.attributes['devicetype']!=nil && e.attributes['devicetype'].downcase.index("cd").nil?) then
					diskName = e.attributes['filename'].tr("\"","").strip().tr("\\","/")
					diskName = File.join(@configPath, diskName) unless diskName[0..0] == "/"
					$log.debug "Adding Disk name to list: [#{diskName}]"
					begin
						vmDisks.push(File.expand_path(diskName))
					rescue
						vmDisks.push(diskName)
					end
					$log.debug "Adding Disk name to list: [#{diskName}]"
					#$log.info "vmDisk Array = #{vmDisks.to_s()}"
				end
			end
		end
		return vmDisks
	end

	def dump_config_to_log(log_level=:warn)
    $log.send(log_level, "VmConfig: Start of configuration info for: #{@configFile}")
    @cfgHash.each { |k, v| $log.send(log_level, "#{k} = #{v}") }
    $log.send(log_level, "VmConfig: End of configuration info for: #{@configFile}")
	end

  def vendor
    "unknown"
  end

  def find_file(filename, file_list=files())
#    basename = File.basename(filename)
#    return file_list.detect {|f| f[:name] == basename}
    return file_list.detect {|f| f[:path] == filename}
  end

	private
	def diskKey?(key)
		return key =~ /^ide\d+:\d+\.filename$/ || key =~ /^scsi\d+:\d+\.filename$/
	end

	def snapshotdiskKey?(key)
		return key =~ /^snapshot\d+.disk\d+.filename$/
	end

	def insert_XML(key, value, xml)
		maj, min, other = key.split(".")

		# Any elements that cannot be split are put into a misc class
		min, maj = maj, maj if min == nil

		if (maj.index(/\d/))
			maj_name = $`.chomp(':')
		else
			maj_name = maj
		end
		if min[0...3] == "mem" || min[0...5] == "nvram" then
			path = [["hardware"], ["memory"]]
		elsif maj_name == "uuid"
			path = [["hardware"], ["bios"]]
			# Drives
		elsif maj_name == "scsi" || maj_name == "ide" || maj_name == "floppy" then
			path = getDevicePath(maj, "disk")
			# Ports
		elsif maj_name == "usb" || maj_name == "parallel" || maj_name == "serial" || maj_name == "sound" || maj_name == "ethernet"
			path = getDevicePath(maj, maj_name)
		elsif maj_name == "snapshot"
			other, min = min, other if other
			path = getSnapShotPath(maj, maj_name, other)
		else
			path = [["vm"], [maj]]
		end

		parent = xml.root
		path.each { |p|
			if p[1] == nil
				ele = MIQRexml.findElement(p[0], parent) if parent.has_elements?
			else
				ele = find_with_attributes(p[0], p[1], parent) if parent.has_elements?
			end

			# Create new node if needed.
			if ele.nil? then
        # Remove any nil keys from the hash
        p[1].delete_if {|k,v| v.nil?} if p[1].kind_of?(Hash)
				parent = parent.add_element(p[0], p[1])
			else
				parent, ele = ele, nil
			end
		}
		parent.add_attribute(min.gsub(':','_'), value) if parent
	end

	def add_disk_stats(xml, miqvm)
    begin
      # Now loop over the xml and find disk files
      xml.find_first("/*/hardware").each_recursive do |e|
        # Find elements that have a filename attribute
        # Loop through the "whole disks" and get the size for this disk
        if e.attributes['filename']
          self.getDiskFileHash.each_pair do |device_id, filename|
            if is_same_disk?(device_id, e)
              if (fstat = self.find_file(e.attributes['filename'], disk_files(miqvm))).nil?
                $log.warn "add_disk_stats - Disk file not found - Details: device_id: [#{device_id}] [#{filename}]"
                next
              end

              $log.info "add_disk_stats - device_id: [#{device_id}] [#{filename}]"

              whole_disk = nil
              whole_disk = miqvm.wholeDisks.detect {|wd| wd.hwId.include?(device_id)} if @vol_mgr_loaded
              size = whole_disk.nil? ? fstat[:provision_size] : whole_disk.size
              
              # Report a disk's size_on_disk as the size of all the files that make up the disk.
              # This includes the base disk and snapshots.
              collective_disk_size = collective_size_on_disk(device_id, disk_files(miqvm))
              size_on_disk = collective_disk_size.blank? ? fstat[:size] : collective_disk_size
              e.add_attributes({'size'=>size, 'size_on_disk'=>size_on_disk, 'disk_type' => fstat[:disk_type]})
            end
          end
        end
      end
    rescue Exception
      $log.error "VmConfig.add_disk_stats [#{$!.class}]-[#{$!}]\n#{$!.backtrace.join("\n")}"
    end
  end

  # Match filenames to loaded disks using the hardware id.  IE scsi0:0 or ide0:0
  def is_same_disk?(hardware_id, xml_element)
    diskId = xml_element.parent.attributes["type"] + xml_element.attributes["id"].to_s
    hardware_id.include?(diskId)
  end

  def normalize_path_names(xml)
    # Now loop over the xml and find disk files
    xml.root.each_recursive {|e| e.add_attribute('filename', resolve_ds_path(e.attributes['filename'])) if e.attributes['filename']}
    xml.find_first("/*/files").each_recursive {|e| e.add_attribute('name', resolve_ds_path(e.attributes['name'])) if e.attributes['name']}
    xml.find_first("/*/volumes").each_recursive {|e| e.add_attribute('virtual_disk_file', resolve_ds_path(e.attributes['virtual_disk_file'])) if e.attributes['virtual_disk_file']}
  end

  def resolve_ds_path(filename)
    #TODO: Determine if we need to do any work here.
    ds, dir, name = split_filename(filename)
    return filename unless ds.nil?

    @ds_replace ||= {}
    @ds_replace.each_pair do |path, ds|
      return filename.sub(path, ds) if filename.include?(path)
    end

    ds_filename = resolve_ds_path_with_vim(filename)
    ds, dir, name = split_filename(ds_filename)
    unless ds.nil?
      idx = filename.index(dir)
      replaced_str = filename[0,idx]
      @ds_replace[replaced_str] = "[#{ds}] "
    end

    return ds_filename
  end

  def host_vim_credentials
    creds = nil
    if $miqHostCfg
      if $miqHostCfg.emsLocal
        creds = $miqHostCfg.ems[$miqHostCfg.emsLocal]
      elsif $miqHostCfg.vimHost
        c = $miqHostCfg.vimHost
        return nil if c[:username].nil?
        creds = {'host'=>c[:address], 'user'=>c[:username], 'password'=>c[:password], 'use_vim_broker'=> c[:use_vim_broker]}
      end

      unless creds.nil?
        creds['password_decrypt'] = MiqPassword.decrypt(creds['password'])
      end
    end
    return creds
  end

  def connect_to_host_vim(conn_reason, vmCfgFile)
    ems_host = host_vim_credentials
    return nil if ems_host.nil?

    begin
      st = Time.now
      ems_display_text = "host(#{ems_host['use_vim_broker'] ? 'via broker' : 'directly'}):#{ems_host['host']}"
      $log.info "#{conn_reason}: Connecting to [#{ems_display_text}] for VM:[#{vmCfgFile}]"

      require 'miq_fault_tolerant_vim'
      hostVim = MiqFaultTolerantVim.new(:ip =>ems_host['host'], :user => ems_host['user'], :pass => ems_host['password_decrypt'], :use_broker => ems_host['use_vim_broker'], :vim_broker_drb_port => ems_host['vim_broker_drb_port'])
      $log.info "#{conn_reason}: Connection to [#{ems_display_text}] completed for VM:[#{vmCfgFile}] in [#{Time.now-st}] seconds"
      return hostVim
    rescue Timeout::Error => err
      $log.error "#{conn_reason}: Connection to [#{ems_display_text}] timed out for VM:[#{vmCfgFile}] with error [#{err}] after [#{Time.now-st}] seconds"
    rescue Exception => err
      $log.error "#{conn_reason}: Connection to [#{ems_display_text}] failed for VM:[#{vmCfgFile}] with error [#{err}] after [#{Time.now-st}] seconds"
    end
    return nil
  end

  def resolve_ds_path_with_vim(filename)
    begin
      vi = nil
      ems = host_vim_credentials
      return (filename) if ems.nil?

      $log.debug "resolve_path_names: emsHost = #{ems['host']}, emsUser = #{ems['user']}, emsPassword = #{ems['password']}" if $log
      vi = MiqVimInventory.new(ems['host'], ems['user'], ems['password_decrypt'])
      return getDsName(filename, vi)

    rescue
      $log.error "VmConfig.resolve_ds_path_with_vim #{$!}\n#{$!.backtrace.join("\n")}"
    ensure
      vi.disconnect if vi
    end
  end

  def getDsName(filename, vi)
    begin
      filename = File.join(File.dirname(@configFile), filename) if File.dirname(filename) == "."
      dsName = vi.datastorePath(filename)
      dsName.sub!("] /", "] ") if dsName.index("] /")
      return dsName
    rescue
      return filename
    end
  end

  def files(miqvm=nil)
    return @files if @files
    log_header = "VmConfig.files"

    @files = []
    if @direct_file_access
      Dir.glob(File.join(@configPath, "/*.*")) do |f|
        s = File.sizeEx(f) rescue 0
        @files << {:path=>f, :name=>File.basename(f), :size=>s, :mtime=>File.mtime(f)}
      end
    else
      begin
        if miqvm.vim
          filePattern = nil
          pathOnly = false
          vimDs, ds = nil
          each_datastore(miqvm) do |ds, dirs|
            begin
              vimDs = miqvm.vim.getVimDataStore(ds)
              dirs.each do |path|
                vimDs.dsFileSearch(filePattern, path, pathOnly).each do |f|
                  @files << {:path=>f['fullPath'], :name=>f['path'], :size=>f['fileSize'].to_i, :mtime=>Time.parse(f['modification'])}
                end
              end
            ensure
              vimDs.release if vimDs rescue nil
            end
          end
        elsif miqvm.rhevm
          # First add the VM's active disk files.
          miqvm.rhevmVm.disks.each { |disk| @files << rhevm_disk_file_entry(disk) }
          # Then add the files associtaed with inactive snapshots.
          miqvm.rhevmVm.snapshots.each do |snap|
            snap.disks.each { |disk| @files << rhevm_disk_file_entry(disk) unless snap[:type] == 'active' }
          end
        end
      rescue
        $log.error "#{log_header} #{$!}\n#{$!.backtrace.join("\n")}"
      end
    end
    disk_files(miqvm)
    return @files
  end
  
  def rhevm_disk_file_entry(disk)
    storage_domain = disk[:storage_domains].first
    storage_id     = storage_domain && storage_domain[:id]
    disk_key       = disk[:image_id].blank? ? :id : :image_id
    fullPath       = storage_id && File.join('/dev', storage_id, disk[disk_key])
    
    return {:path=>fullPath, :name=>disk[disk_key], :size=>disk[:actual_size].to_i}
  end
  private :rhevm_disk_file_entry

  def disk_files(miqvm=nil)
    return @disk_files if @disk_files
    @disk_files = []
    if @direct_file_access
      @disk_files = files(miqvm)
    else
      begin
        vim_disks = {}
        if miqvm.vimVm
          miqvm.vimVm.devices.each do |d|
            next if d['capacityInKB'].nil?
            next if (filename = d.fetch_path('backing','fileName')).nil?
            disk = vim_disks[filename.to_s] = {}
            disk[:disk_type] = (d.fetch_path('backing','thinProvisioned') == 'true') ? 'thin' : 'thick'
            disk[:provision_size] = d['capacityInKB'].to_i * 1024
            disk[:display_name] = d.fetch_path('deviceInfo','label').to_s
            disk[:vim_index] = d['key'].to_i
            disk[:disk_mode] = d['diskMode']
          end

          filePattern = nil
          pathOnly = false
          each_datastore(miqvm) do |ds, dirs|
            begin
              vimDs = miqvm.vim.getVimDataStore(ds)
              dirs.each do |path|
                vimDs.dsVmDiskFileSearch(filePattern, path, pathOnly).each do |f|
                  d = {:path=>f['fullPath'], :name=>f['path'].to_s, :size=>f['fileSize'].to_i, :mtime=>Time.parse(f['modification'])}
                  dh = vim_disks[d[:path]]
                  d.merge!(dh) unless dh.nil?
                  @disk_files << d
                end
              end
            ensure
              vimDs.release if vimDs rescue nil
            end
          end
        elsif miqvm.rhevmVm
          miqvm.rhevmVm.disks.each do |disk|
            storage_domain = disk[:storage_domains].first
            storage_id = storage_domain && storage_domain[:id]
            disk_key = disk[:image_id].blank? ? :id : :image_id
            fullPath = storage_id && File.join('/dev', storage_id, disk[disk_key])
            d = {:path=>fullPath, :name=>disk[:name].to_s, :size=>disk[:size].to_i}
            @disk_files << d
          end
        end
      rescue Exception
        $log.error "VmConfig.disk_files #{$!}\n#{$!.backtrace.join("\n")}"
      end
    end
    return @disk_files
  end

	def add_file_sizes(xml, miqvm)
    return if miqvm.nil?
    begin
      node = xml.root.add_element("files")
      total_size = 0
      files(miqvm).each do |fh|
        total_size += fh[:size]
        node.add_element('file', {"name"=>fh[:name], "size_on_disk"=>fh[:size]})
      end
      # Add the total size to the "files" node
      node.add_attribute("size_on_disk", total_size)

      free_space = 0; disk_capacity = 0
      if miqvm && @vol_mgr_loaded
        # Make sure we have the volume manager loaded
        vmRoot = miqvm.vmRootTrees[0]
        if vmRoot
          miqvm.wholeDisks.each {|d| disk_capacity += d.size}
          rootAdded = false
          vmRoot.fileSystems.each do |fsd|
            $log.info "FileSystem: #{fsd.fsSpec}, Mounted on: #{fsd.mountPoint}, Type: #{fsd.fs.fsType}, Free bytes: #{fsd.fs.freeBytes}"
            # The root volume can appear more than once, so only add it one time.
            if fsd.mountPoint=="/"
              if rootAdded == false
                free_space += fsd.fs.freeBytes
                rootAdded = true
              end
            else
              free_space += fsd.fs.freeBytes
            end
          end
        end

        # Now calculate free/used percent against size on disk
        if !free_space.zero? && !disk_capacity.zero?
          # Calculate the percentage of free space
          percent_free = free_space.to_f / disk_capacity.to_f * 100

          # Populate formated text fields
          node.add_attributes("pct_free_wrt_size_on_disk"=>percent_free, "pct_used_wrt_size_on_disk"=>(100-percent_free))
          node.add_attributes("disk_free_space"=>free_space, "disk_capacity"=>disk_capacity)
        end
      end
      node.add_attributes("disk_free_space"=>free_space, "disk_capacity"=>disk_capacity)
    rescue => err
    end
	end

  def load_vim_snapshots(miqvm)
    begin
      if @direct_file_access==false && miqvm && miqvm.vim
        # If the VM does not have snapshots we can stop here
        return if miqvm.snapshots.nil?
        ds, dir, name = split_filename(miqvm.vmConfigFile)
        
        # We need to connect to the host to get the snapshot file content
        hostVim = nil
        if miqvm.vim.isVirtualCenter?
          hostVim = connect_to_host_vim('snapshot_metadata', miqvm.vmConfigFile)
          return if hostVim.nil?
          vimDs = hostVim.getVimDataStore(ds)
        else
          vimDs = miqvm.vim.getVimDataStore(ds)
        end

        configType = "vmx"
        require configType + "Config"
        extend Kernel.const_get(configType.capitalize + "Config")
        snapshot_file = File.join(dir, File.basename(name, ".*") + ".vmsd")
        Timeout::timeout(60) do
          process_file(self.convert_vmsd(vimDs.get_file_content(snapshot_file)))
        end
        @cfgHash
      end
    rescue Timeout::Error => err
      $log.warn "Timeout reached transferring snapshot metadata for config file [#{miqvm.vmConfigFile}].  Message:[#{err}]"
    rescue => err
      $log.warn "Unable to process snapshot metadata for config file [#{miqvm.vmConfigFile}].  Message:[#{err}]"
    ensure
      vimDs.release   if vimDs   rescue nil
      hostVim.release if hostVim rescue nil
    end
  end

  def each_datastore(miqvm)
    files = [@configFile]
    each_disks() {|device_id, filename| files << filename}

    ds = Hash.new {|h,k| h[k]={}}
    files.each do |f|
      dsName, dir, name = split_filename(f)
      ds[dsName][dir] = true #unless dsName.nil?
    end

    ds.each_pair {|ds, h| yield(ds, h.to_a.transpose.first)}
  end

	def getDevicePath(name, endType)
		# Initialize variables
		full_pos, maj_pos, device = nil, "0", name
		# If the name contains a number, use it as the id

    if name.index(/\d/)
		  device   = $`.chomp(':')
      maj_pos  = $&
      full_pos = "#{$&}#{$'}"
    end

		#These devices only have 1 position number, and should be grouped under a controller
		maj_pos = nil if ["ethernet", "floppy", "parallel", "serial"].include?(device)

		ret = [["hardware"], ["bus", {"type"=> "pci"}], ["controller", {"type"=> device, "id"=> maj_pos}]]
		# Add a device type if the major position and full position differ, otherwise
		# we are processing a controller element.
		ret << ["device", {"type"=> endType, "id"=> full_pos}] if maj_pos != full_pos
		return ret
	end

	def getSnapShotPath(name, endType, disk)
		# Initialize variables
		full_pos, maj_pos, device, pos_idx = split_data(name)

		return [["vm"], ["snapshots"]] if pos_idx.nil?
		ret = [["vm"], ["snapshots"], [endType, {"id"=> full_pos}]]

		if disk
			a, b, subDevice, c = split_data(disk)
			diskPath = getSnapShotPath(disk, subDevice, nil)
			ret << diskPath.pop
		end

		return ret
	end

	def add_snapshot_size(xml, miqvm)
    adjust_snapshot_aligment(xml)

		# First we need to loop through the snapshots and add flat files for any
		# disks that are just descriptor files
		xml.find_each("//*/snapshots/snapshot/disk") do |e|
			unless e.attributes['filename'].nil?
        find_additional_disk_files(e.attributes['filename']) do |f|
          e.parent.add_element("disk", {"filename"=>f[:path]})
        end
			end
		end

		# Now loop through the filename and collect stats  (date/time/size)
		node = xml.find_first("//*/snapshots")
		node.each_recursive do |e|
			if (e.attributes.include?("filename"))
				begin
					filename = normalize_file_path(e.attributes['filename'])
          next if (fstat = self.find_file(filename)).nil?
					e.add_attribute("size_on_disk",  fstat[:size])
					e.add_attribute("mdate_on_disk", fstat[:mtime].getutc.iso8601(6))
				rescue => err
					# Ignore errors here, we will try to load almost anything.
          $log.error "VmConfig.add_snapshot_size [#{$!.class}]-[#{$!}]\n#{$!.backtrace.join("\n")}"
				end
			end
		end unless node.nil?
	end

  def adjust_snapshot_aligment(xml)
    sn = {}
    sn_root = xml.find_first("//*/snapshots")

    unless sn_root.nil?
      disks_by_snap = disks_by_snapshot_and_node()
      xml.find_each("//*/snapshots/snapshot") {|s| sn[s.attributes[:uid]] = s}

      sn_list = sn.sort {|a,b| a[1].attributes[:uid].to_s<=>b[1].attributes[:uid].to_s}
      clear_snapshot_disks(sn_list)

      sn_list.each do |(id, snapshot)|
        parent = snapshot.attributes[:parent]
        unless parent.nil? || sn[parent].nil?
           disks_by_snap[id.to_s]['disks'].each do |device_id, filename|
             sn[parent].add_element(:disk, {:node=>device_id, :filename=>filename})
           end
        end

        filename = normalize_file_path(snapshot.attributes[:filename])
        snapshot.add_element("vmem", {"filename"=>filename}) if self.find_file(filename)
      end

      current = sn[sn_root.attributes[:current]]
      unless current.nil?
        disks_by_snap[:current]['disks'].each do |device_id, filename|
          current.add_element(:disk, {:node=>device_id, :filename=>filename})
        end
      end
    end
  end

  def clear_snapshot_disks(sn_list)
    sn_list.each do |(id, snapshot)|
      delete_items = []
      snapshot.each {|d| delete_items << d if d.name == 'disk'}
      delete_items.each(&:remove!)
    end
  end

	def split_data(name)
		# Initialize variables
		full_pos, maj_pos, device = nil, "0", name
		# If the name contains a number, use it as the id
		pos_idx = name.index(/\d/)
		if pos_idx
			full_pos = name[pos_idx..-1]
			maj_pos, device = full_pos[0..0]
			device = name[0...pos_idx]
		end
		return full_pos, maj_pos, device, pos_idx
	end

	def find_with_attributes(findKey, findAttr, xmlNode)
		xmlNode.each_element { |e|
			if e.name == findKey
				found = true
        findAttr.each_pair { |k,v|
          found = false if e.attributes[k] != v
        }
        return e if found
      end
		}
		return nil
	end

  def add_volumes(xml, miqvm)
    return unless @vol_mgr_loaded
    return if miqvm.nil?
    xml.root << miqvm.volumeManager.toXml.root
  end

  def configuration_fixup()
    fixup_keys = []
    @cfgHash.each_pair do |k,v|
      # If the cdrom does not have a filename force the 'startconnected' to false.
      # This is to handle "Client Device" settings in VC that does not maintain the startconnected value.
      if k.include?('.devicetype') && v.include?('cdrom')
        dskKey = k.gsub('.devicetype', '')
        fixup_keys << dskKey if @cfgHash[dskKey + ".filename"].to_s.gsub('"', '').blank?
      end
    end
    fixup_keys.each {|k| @cfgHash["#{k}.startconnected"] = 'false'}
  end

  def collective_size_on_disk(device_id, files=[])
    total_size = 0
    disks_by_node[device_id].each do |disk_name|
      file = files.detect {|f| f[:path]==disk_name}
      total_size += file[:size] unless file.nil?
      find_additional_disk_files(disk_name) {|f| total_size += f[:size]} if @direct_file_access
    end
    return total_size
  end

  def split_filename(filename)
    file = filename.dup
    ds = nil
    if file =~ /^\[.*\] /
      ds = $&.strip[1..-2]
      file = $'
    end
    return ds, File.dirname(file), File.basename(file)
  end

  def base_disk_name(filename)
    ds, dir, name = split_filename(filename)
    if name =~ /-\d{6}[-|\.]/
      #puts "#{$`}<<#{$&}>>#{$'}"
      return nil if $`.nil?
      basename = $`
    else
      basename = File.basename(name, '.*')
      basename.gsub!('-flat', '')
    end

    key = File.join(dir, basename)
    key = "[#{ds}] " + key unless ds.nil?
    return key
  end

  def self.to_h(filename)
    dataHash = {}
    data = filename
    data = File.read(filename) unless filename.include?("\n")
    data.each_line do |l|
      l.strip!
      next if l[0..0] == '.' || l[0..0] == '#' || l.empty?

      parent = l.split('=')[0].split('.').inject({:current_level=>dataHash, :hash=>nil, :key=>nil}) do |h, k|
        a1 = h[:current_level][k.strip.to_sym] ||= {}
        a1 = h[:current_level][k.strip.to_sym] = {:_default => a1} unless a1.kind_of?(Hash)
        {:current_level=>a1, :hash=>h, :key=>k.strip.to_sym}
      end
      uh, key = parent[:hash][:current_level], parent[:key]
      kkey = key.to_s.strip.to_sym
      value = eval_config(l.split('=')[1], kkey)
      uh[key] = value
    end
    return dataHash
  end

  def self.eval_config(value, key)
    value.strip!
    value = value[1..-2] if value[0,1] == '"' and value[-1,1] == '"'
    [true, false].each {|b| return b if value.downcase == b.to_s}
    return value.to_i if value =~ /^\d/
    return nil if value.blank?
    return value
  end

  def normalize_file_paths(config_file=@configFile)
    @cfgHash.each_pair do |k,v|
      @cfgHash[k] = normalize_file_path(v, config_file) if k.include?('.filename')
    end
  end

  def normalize_file_path(filename, config_file=@configFile)
    cfg_ds, cfg_dir, cfg_name = split_filename(config_file)
    ds, dir, name = split_filename(filename)
    if dir.blank? || dir == '.'
      name = File.join(cfg_dir, name)
      name = "[#{cfg_ds}] " + name unless cfg_ds.nil?
      return name
    else
      # Check for files that do not have a ds when the config file does
      return resolve_ds_path(filename) if cfg_ds && ds.nil?
    end
    return filename
  end

  def disks_by_node()
    result = Hash.new {|h,k| h[k]=[]}

    # Keep track of the disk we process so they do not get counted twice.
    # This handles independent-persistent disk that do not take part in snapshots but will
    # show up in each snapshot's disk list.
    processed_disks = []

    normalize_file_paths()
    getDiskFileHash.each_pair do |disk_id, path|
      unless processed_disks.include?(path)
        result[disk_id] << path
        processed_disks << path
      end
    end

    getSnapshotDiskFileHash.each_pair do |id,h|
      h['disks'].each_pair do |disk_id, path|
        unless processed_disks.include?(path)
          result[disk_id] << path
          processed_disks << path
        end
      end
    end

    return result
  end

  def each_disks()
    # Call disks_by_node since it will remove duplicate disks
    disks_by_node.each_pair {|device_id, disks| disks.each {|d| yield(device_id, d)}}
  end

  def disks_by_snapshot_and_node()
    result = Hash.new {|h,k| h[k]={}}
    getSnapshotDiskFileHash.each_pair {|id,h| result[id] = h}

    result[:current] = {'disks' => {}}
    current_disks = result[:current]['disks']
    getDiskFileHash.each_pair do |device_id, d|
      # Independent disks do not par-take in snapshots.  Check the mode of the parent disk.
      next if @cfgHash["#{device_id}.mode"].to_s.include?('independent')
      current_disks[device_id] = d
    end

    return result
  end

  def find_additional_disk_files(filename)
    ds ,dir, name = split_filename(normalize_file_path(filename))
    dfBase, ext = File.basename(name, ".*"), File.extname(name)
    %w{-flat -delta}.each do |disk_type|
      search_filename = file_join(dir, dfBase + disk_type + ext)
      search_filename = "[#{ds}] " + search_filename unless ds.nil?
      f = self.find_file(search_filename)
      yield(f) unless f.nil?
    end
  end

  # Ensures that windows paths use forward slashes to full path lookups work.
  def file_join(*args)
    filename = File.join(*args)
    filename.gsub!('\\','/') if filename[1,1] == ':'
    filename
  end
end
