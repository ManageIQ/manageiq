$:.push("#{File.dirname(__FILE__)}/../../../util")
require 'extensions/miq-file'
require 'enumerator'

module Win32
	class SystemPath
    # BCD WMI Provider Enumerations (values)
    #http://msdn.microsoft.com/en-us/library/cc441427(VS.85).aspx
    SYSTEM_STORE_GUID = '{9dea862c-5cdd-4e70-acc1-f32b344d4795}'
    BCD_BOOTMGR_OBJECT_DEFAULTOBJECT  = '23000003' #0x23000003
    BCD_OS_LOADER_DEVICE_OSDEVICE     = '21000001' #0x21000001
    BCD_OS_LOADER_STRING_SYSTEMROOT   = '22000002' #0x22000002
    BCD_LIBRARYSTRING_DESCRIPTION     = '12000004' #0x12000004

		def self.registryPath(fs=nil, root=nil)
			File.join(self.system32Path(fs, root), "config")
		end

		def self.system32Path(fs=nil, root=nil)
			return File.join(root, "system32") if root
			File.join(self.systemRoot(fs), "system32")
		end

    def self.systemRoot(fs=nil, si=nil)
      si = self.systemIdentifier(fs) if si.nil?
      raise(MiqException::MiqVmMountError, "Filesystem does not contain system root identifiers.") if si.blank?
      system32_dir = File.join(si[:system_root], 'system32')
      raise(MiqException::MiqVmMountError, "Filesystem does not contain system root folder (#{system32_dir}).") unless fs.fileDirectory?(system32_dir)
      return si[:system_root]
    end

		def self.systemIdentifier(fs=nil, options={})
			# If we are not passed a fs handle return the %systemRoot% from the environment
			if fs.nil?
				raise(MiqException::MiqVmMountError, "System root not available through environment variables.") if ENV["SystemRoot"].nil?
				return File.normalize(ENV["SystemRoot"])
			end

			# Use the boot.ini file to get the starting path to the Windows folder
			fn =[{:file=>"/boot.ini", :type=>:boot_ini}, {:file=>"/boot/BCD", :type=>:bcd}, {:file=>'/Windows/System32/config/SYSTEM', :type=>:registry_file}]
			drive_letter = fs.pwd.to_s[0,2]
			if drive_letter[1,1] == ':'
				fs.chdir("#{drive_letter}/")
				fn.each {|f| f[:file] = "#{drive_letter}#{f[:file]}"}
			end

			# Determine where the initial boot information is stored (boot.ini or BCD registry
			boot_cfg = fn.detect {|b| fs.fileExists?(b[:file])}

			# If we did not find either identifier above raise an error.
		  return {} if boot_cfg.nil?

      # Set default system root path
      boot_cfg[:system_root] = "/Windows"

      $log.debug "Boot info stored in: [#{boot_cfg.inspect}]" if $log
      case boot_cfg[:type]
      when :boot_ini
        begin
          if fs.kind_of?(MiqFS)
            boot_cfg_text = fs.fileOpen(boot_cfg[:file]).read
            $log.warn "Contents of <#{boot_cfg[:file]}>\n#{boot_cfg_text}" if $log && options[:debug] == true
            boot_cfg[:system_root] = $'.split("\n")[0].split("\\")[1].chomp if boot_cfg_text =~ /default=/
          end
          boot_cfg[:system_root].strip!
          boot_cfg[:system_root] = "/#{boot_cfg[:system_root]}"
        rescue RuntimeError => err
          $log.warn "Win32::SystemPath.systemRoot [#{err}]" if $log
        end
      when :bcd
        boot_cfg.merge!(self.parse_bcd(fs))
        boot_cfg[:system_root].gsub!('\\', '/') unless boot_cfg[:system_root].nil?
      when :registry_files
        #TODO: Needs to change to support BCD on different partition.  This is just a work-around
      end

			return  boot_cfg
		end

    def self.parse_bcd(fs)
      result = {}
      reg = RemoteRegistry.new(fs, XmlHash, '/boot')
      xml = reg.loadBootHive()

      # Find the GUID of the default Boot element
      default_guid_path = "HKEY_LOCAL_MACHINE\\BCD\\Objects\\#{SYSTEM_STORE_GUID}\\Elements\\#{BCD_BOOTMGR_OBJECT_DEFAULTOBJECT}\\Element"
      default_os = MIQRexml.findRegElement(default_guid_path, xml.root)
      default_os = MIQRexml.findRegElement("HKEY_LOCAL_MACHINE\\BCD\\Objects\\#{default_os.text}\\Elements", xml.root)

      [BCD_OS_LOADER_DEVICE_OSDEVICE, :os_device, BCD_OS_LOADER_STRING_SYSTEMROOT, :system_root,
       BCD_LIBRARYSTRING_DESCRIPTION, :os_description].each_slice(2) do |key_id,name|
        device = MIQRexml.findRegElement("#{key_id}\\Element", default_os)
        result[name] = device.text unless device.nil?
      end

      # Decode disk signature
      unless result[:os_device].nil?
        d = result[:os_device].split(',')
        result[:disk_sig] = (d[59] + d[58] + d[57] + d[56]).to_i(16)
      end
      return result
    end
	end
end
