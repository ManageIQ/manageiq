require 'remote-registry'

module Win32
	class SystemPath
		def self.driveAssignment(fs)
      log_header = "MIQ(SystemPath.driveAssignment)"
			drives = []
			regHnd = RemoteRegistry.new(fs, true)
			xml = regHnd.loadHive("system", ["MountedDevices"])

      # Find the MountedDevices node
      node = nil
      xml.elements.each {|e| node = e if e.name == :key && e.attributes[:keyname] == 'MountedDevices'}

      unless node.nil?
        node.each_element do |e|
          if e.attributes[:name].include?("DosDevices") && e.text.length <= 36
            data = e.text.split(",")

            # The partition signature is derived from the DiskID and the partition's starting
            # sector number. The DiskID (sometimes called the "NT serial number") is a group of
            # four bytes in the master boot sector (LBA 0) at location 01B8h. Each partition's
            # starting sector number is doubled and combined with the DiskID to form a unique
            # signature for that partition. For example, consider a disk with the serial number
            # 3D173D16h (hexadecimal) and a partition starting at LBA 44933868 (decimal). Double
            # the sector number (89867736) and convert to hexadecimal (055B45D8h). If this partition
            # were designated E:, the corresponding registry values would be:
            #
            # [HKEY_LOCAL_MACHINE\System\MountedDevices]
            # \??\Volume{...} = 16 3d 17 3d 00 d8 45 5b 05 00 00 00
            # \DosDevices\E:  = 16 3d 17 3d 00 d8 45 5b 05 00 00 00

            drives << {:device=>e.attributes[:name],
              :name=>e.attributes[:name].split("\\")[-1],
              :raw_data=>e.text,
              :serial_num => "0x#{data[3]}#{data[2]}#{data[1]}#{data[0]}".to_i(16),
              :starting_sector => "0x#{data[8]}#{data[7]}#{data[6]}#{data[5]}".to_i(16) / 2}
          elsif e.attributes[:name].include?("DosDevices")  && e.text.length <= 100
            $log.warn "#{log_header} Skipping disk #{e.attributes[:name]} - (#{e.text.length})#{e.text}"
          end
        end
      end

      # If we do not find this key we cannot map disks with the proper drive letter.
      # This is a good sign that the OS is in a sysprep state and not fully installed.
      if drives.empty?
        $log.warn "#{log_header} The registry does not contain a mounted device list.  [Possible cause: The OS is in a pre-installed state.]"
        xml.to_xml.write(xml_str='',0)
        $log.warn "#{log_header} HKLM\\SYSTEM\\MountedDevices - START\n#{xml_str}"
        $log.warn "#{log_header} HKLM\\SYSTEM\\MountedDevices - END"

        os_install_loc = Win32::SystemPath.systemIdentifier(fs, :debug=>true)
        $log.warn "#{log_header} System Install location: <#{os_install_loc.inspect}>"
      end

			return drives
		end
  end
end
