$:.push("#{File.dirname(__FILE__)}/../../util")
$:.push("#{File.dirname(__FILE__)}/../../VMwareWebService")
$:.push("#{File.dirname(__FILE__)}/../../kvm")

require 'ostruct'
require 'miq-xml'
require 'runcmd'
require 'miq-password'
require 'MiqKvmHost'

module MiqLinux
    
    class HostLinuxOps
        def initialize(ost)
          @hyperVisors = [MiqKvmHost].inject([]) {|h, klass| h << klass.new if klass.new.is_available? rescue nil; h}
        end
        
        def GetHostConfig(ost)
            xml = MiqXml.createDoc("<host_configuration><OperatingSystem/></host_configuration>")
            
            #
            # Where we'll store OS information.
            #
            xmlNode = MIQRexml.findElement("OperatingSystem/Configuration", xml.root)
            
            Dir.glob("/etc/*-release") do |rf|
                dist = File.basename(rf, "-release")
                next if dist == "vmware"
                el = xmlNode.add_element('value', {'name'=>'ProductType', 'type'=>'1'})
                el.add_text(dist)
                el = xmlNode.add_element('value', {'name'=>'ProductName', 'type'=>'1'})
                el.add_text(IO.read(rf).chomp)
            end
            el = xmlNode.add_element('value', {'name'=>'ComputerName', 'type'=>'1'})
            el.add_text(`uname -n`.chomp)
            
            #
            # Get the IP address of the ESX service console.
            #
            ifcstr = `ifconfig | sed -e "/^vswif0/,/^$/p" -e d | grep "inet addr:"`
            ipaddr = /^.*inet addr:([^\s]+)\s/.match(ifcstr)
            el = xmlNode.add_element('value', {'name'=>'IPAddress', 'type'=>'1'})
            el.add_text(ipaddr[1]) if ipaddr
            el.add_text("") unless ipaddr
            
            #
            # Get the hypervisor information
            #
            begin
                hvInfo = `vmware -v`.chomp.split(' ')
                vendor = hvInfo.shift
                build  = hvInfo.pop.delete("-build")
                ver    = hvInfo.pop
                prod   = hvInfo.join(" ")
                xml.root.add_element("hypervisor", {"vendor"=>vendor,"product"=>prod,"version"=>ver,"build"=>build})
            rescue
            end

            ost.xml = true
            ost.encode = true
            ost.value = xml.to_s
        end # def GetHostConfig
        
        def GetVMs(ost)
            ra = []
            
            if !$miqHostCfg || !$miqHostCfg.emsLocal
                localPaths = MiqUtil.runcmd("vmware-cmd -l", ost.test).split("\n")
                dsPaths = localPaths
            else
                require 'VimInventory'
        		ems = $miqHostCfg.ems[$miqHostCfg.emsLocal]
        		$log.debug "GetVMs: emsHost = #{ems['host']}, emsUser = #{ems['user']}, emsPassword = #{ems['password']}" if $log
			vi = VimInventory.new(ems['host'], ems['user'], MiqPassword.decrypt(ems['password']))
        		
            # Make sure we have an array to process, even if the call returns nil
        		dsPaths = vi.getVMs(:localPath => false).to_miq_a
						# Ensure the return value is an array 
        		vi.disconnect
        		
        		localPaths = []
        		dsPaths.each { |dp| localPaths << vi.localVmPath(dp) }
            end
            
            (0...dsPaths.length).each do |i|
                $log.debug "GetVMs: dsPath = #{dsPaths[i]}" if $log
                $log.debug "GetVMs: localPath = #{localPaths[i]}" if $log
                begin
      				cfg = VmConfig.new(localPaths[i])
      				ra.push({:name => cfg.getHash["displayname"], :vendor => cfg.vendor, :location => dsPaths[i], :guid=>Manageiq::BlackBox.vmId(localPaths[i])})
      			rescue => err
      			    $log.warn "GetVMs: could not obtain configuration for VM: #{localPaths[i]}"
      			    $log.warn "GetVMs: skipping VM, error: #{err}"
      			    $log.warn err.backtrace.join("\n")
      			end
  		    end
  		    if !ost.fmt
  		        ost.value = ""
  			    ra.each { |h| ost.value += "#{h[:name]}\t#{h[:vendor]}\t\"#{h[:location]}\"\n" }
										   
  			    return
  		    end
  		    ost.value = ra.inspect
  	    end # def GetVMs

        def ems
          return nil if @hyperVisors.empty?
          return @hyperVisors.first.class
        end
  	  
    end # class HostLinuxOps
    
end # module MiqLinux

