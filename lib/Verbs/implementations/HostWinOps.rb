$:.push("#{File.dirname(__FILE__)}/../../metadata/VmConfig")
$:.push("#{File.dirname(__FILE__)}/../../metadata/util/win32")
$:.push("#{File.dirname(__FILE__)}/../../util")
$:.push("#{File.dirname(__FILE__)}")

require 'ostruct'
require 'miq-xml'
require 'win32/registry'
require 'runcmd'
require 'VmConfig'
require 'win32/miq-wmi'
require 'VmwareWinCom'
require 'MicrosoftWinCom'
require 'time'
require 'miq-powershell-daemon'

module MiqWin
	class HostConfigData
		def initialize(ost)
			# Get a handle to the VMWare and MSVS objects and check if the interfaces 
			# are available.  If not, set the handle to nil so we know not to use it.
      @hyperVisors = [MSVirtualServerCom, VmwareCom].inject([]) {|h, klass| h << klass.new rescue nil; h}
		end
		
		def GetHostConfig(ost)
			begin
				# Tell the caller that we are sending back an xml value and 
				# it may need to be encoded if transferred over a WS.
				ost.xml = ost.encode = true
				ost.value = to_xml.to_s
			rescue => err
				ost.error = err.to_s
			end
			ost.xml = ost.encode = true
		end
		
		def GetVMs(ost)
			ra = []
      @hyperVisors.each do |h|
        h.registeredVms.each do |l|
          $log.debug "GetVMs: vmwareCom.registeredVM = #{l}" if $log
          l.strip!
          cfg = VmConfig.new(l)
          ra.push({:name => cfg.getHash['displayname'], :vendor => cfg.vendor, :location => File.path_to_uri(l), :uid_ems => cfg.getHash['ems.uid']}) #, :guid=>Manageiq::BlackBox.vmId(l)})
        end unless h.nil?
      end
					
			if !ost.fmt
				ost.value = ""
				ra.each { |h| ost.value += "#{h[:name]}\t#{h[:vendor]}\t\"#{h[:location]}\"\n" }
				return
			end
			
			ost.value = ra.inspect
		end

    def ems
      return nil if @hyperVisors.empty?
      return @hyperVisors.first.class
    end
		
#		private
		def to_xml
			xml = MiqXml.createDoc("<host_configuration></host_configuration>")
      xmlNode = osNode = xml.root.add_element("system").add_element("os")
      osNode.add_attribute('type', 'windows')

      wmi = WMIHelper.connectServer()
      wmi.getObject("Win32_OperatingSystem") do |os|
        osNode.add_attribute('system_root', os.WindowsDirectory.AsciiToUtf8)
        osNode.add_attribute('productid', os.SerialNumber)
        osNode.add_attribute('build', os.BuildNumber)
        osNode.add_attribute('version', os.Version.gsub(os.BuildNumber, '').chomp('.'))
        osNode.add_attribute('service_pack', os.CSDVersion)
        osNode.add_attribute('product_name', os.Caption.AsciiToUtf8.split(' ')[1..-1].join(' '))
      end

      Win32::Registry::HKEY_LOCAL_MACHINE.open('SYSTEM\\CurrentControlSet\\Control\\ComputerName\\ComputerName') do |reg|
        osNode.add_attribute('machine_name', reg['ComputerName'])
      end

      Win32::Registry::HKEY_LOCAL_MACHINE.open('SYSTEM\\CurrentControlSet\\Control\\ProductOptions') do |reg|
        osNode.add_attribute('product_type', reg['ProductType'])
      end

			# Include virtual network adapter information
#			xmlNode2 = xmlNode2.elements[1]
#			items = wmi.run_query("SELECT DeviceID, GUID, Name FROM Win32_NetworkAdapter WHERE Name LIKE 'VMWare%' AND GUID IS NOT NULL") do |item|
#				xmlNode3 = xmlNode2.add_element("key", {"keyname"=>item.DeviceID, "fqname"=>""})
#				xmlNode3.add_element("value", {"name"=>"ServiceName", "type"=>"1"}).text = item.GUID
#				xmlNode3.add_element("value", {"name"=>"Description", "type"=>"1"}).text = item.Name
#			end

			# Include system information
			wobj = nil; hardware = ""

      # Not all Windows levels support these fields.  DNSHostName added in Vista.
      wmi.getObject("Win32_ComputerSystem") do |cs|
  			["Domain", "DNSHostName"].each {|p| xmlNode.add_element("value", {"name"=>p, "type"=>"1"}).text = cs[p] if cs[p] rescue nil}
    		hardware += "memsize = \"#{(cs.TotalPhysicalMemory.to_i / (1024 * 1024)).to_i}\"\n"
      end

			items = wmi.getObject("Win32_Processor")
      items.each do |p|
        ncpus = p.NumberOfCores rescue items.count
        hardware += "numvcpus = \"#{ncpus}\"\n"
        hardware += "cpuspeed = \"#{p.MaxClockSpeed}\"\n"
        hardware += "cputype = \"#{p.Name}\"\n"
        osNode.add_attribute('architecture', p.AddressWidth)
        break
      end
			
			wmi.getObject("Win32_OperatingSystem") {|i| hardware += "guestos = \"#{i.caption.strip}\"\n" }
			wmi.getObject("Win32_BIOS").each {|i| hardware += "uuid.bios = \"#{i.Description}\"\n" }

      networks = osNode.parent.add_element("networks")
			idx = 0
			wmi.run_query("select * from Win32_NetworkAdapterConfiguration where IPEnabled = true").each do |n|
				if n.DefaultIPGateway
					prefix = "Ethernet#{idx}"
					hardware += prefix + ".present = \"TRUE\"\n"
					hardware += prefix + ".connectionType = \"bridged\"\n"
					hardware += prefix + ".generatedAddress = \"#{n.MacAddress}\"\n"
					hardware += prefix + ".ipaddress = \"#{n.IPAddress[0]}\"\n"
					hardware += prefix + ".dns_hostname = \"#{n.DNSHostName}\"\n"
					hardware += prefix + ".dns_domain = \"#{n.DNSDomain}\"\n"
					idx+=1

          network = networks.add_element("network", {'description'=>n.description})
          network.add_attributes('ipaddress'=>n.IPAddress[0], 'domain'=>n.DNSDomain, 'hostname'=>n.DNSHostName)
          network.add_attributes('guid'=>n.settingID[1..-2], 'dhcp_server'=>n.DHCPServer, 'default_gateway'=>n.DefaultIPGateway[0])
          network.add_attributes('subnet_mask'=>n.IPSubnet[0], 'dns_server'=>n.DNSServerSearchOrder[0]) if n.DNSServerSearchOrder
          network.add_attribute('dhcp_enabled', n.DHCPEnabled == true ? '1' : '0')
          network.add_attribute('lease_expires', Time.parse(n.DHCPLeaseExpires.split('.')[0]).utc.iso8601) if n.DHCPLeaseExpires
          network.add_attribute('lease_obtained', Time.parse(n.DHCPLeaseObtained.split('.')[0]).utc.iso8601) if n.DHCPLeaseObtained
        end
    end
            
			wmi.getObject("Win32_DiskDrive").each do |i|
				prefix = "#{i.InterfaceType.to_s.downcase}#{i.SCSIBus}:#{i.Index}"
				hardware += prefix + ".size = \"#{i.Size}\"\n"
				hardware += prefix + ".present = \"TRUE\"\n"
      end
			
			
      #i = 0
      #mgmt.InstancesOf("Win32_LogicalDisk where DriveType = 3").each do |item|
      #  prefix = dType + "0:" + i.to_s
      #  hardware += prefix + ".present = \"TRUE\"\n"
      #  hardware += prefix + ".size = \"#{item.Size}\"\n"
      #  hardware += prefix + ".free_space = \"#{item.FreeSpace}\"\n"
      #  hardware += prefix + ".file_system = \"#{item.FileSystem}\"\n"
      #end
			
			xml2 = VmConfig.new(hardware).toXML(false)
			xml2.root.name = "host_hardware"
			xml.root << xml2.root
			
			#Add vendor version info
      @hyperVisors.each {|h| xml.root.add_element("hypervisor", h.hypervisorVersion()) unless h.nil?}
			return xml
		end
		
		def readRegistry(xmlNode, regKey, includeKeyNode=false, recursive=false, depth=-1)
			Win32::Registry::HKEY_LOCAL_MACHINE.open(regKey) do |reg|
				if includeKeyNode
					xmlNode = xmlNode.add_element("key", {"keyname"=>regKey[/\\([^\\]+)$/, 1], "fqname"=>regKey.gsub('\\', '/')})
				end

				# Skip binary data (type == 3)
				reg.each_value { |name, type, data| xmlNode.add_element("value", {"name"=>name, "type"=>type}).text = data.to_s unless type == 3 }
			
				if recursive and depth != 0
					reg.each_key do |subKey, wtime|
						readRegistry(xmlNode, regKey + '\\' + subKey, true, true, depth - 1)
					end 
				end
			end
		end

    def PowershellCommand(ost)
      begin
        ps_script = ost.args[0]
        return_type = ost.args[1]
        ps = MiqPowerShell::Daemon.new()
        ost.value = ps.run_script(ps_script, return_type)
        ost.value = ost.value.to_s if return_type == 'xml'
      ensure
        unless ps.nil?
          ost.ps_log_messages = ps.get_log_messages
          ps.disconnect
        end
      end
    end
	end
end

#if __FILE__ == $0 then
#  begin
#    ost = OpenStruct.new("fmt"=>true)
#    MiqWin::HostConfigData.new(ost).to_xml().write(STDOUT,0)
#    MiqWin::HostConfigData.new(ost).GetVMs(ost)
#    puts "\n\n#{ost.value}"
#  rescue => err
#    puts err
#    puts err.backtrace.join("\n")
#  end
#end
