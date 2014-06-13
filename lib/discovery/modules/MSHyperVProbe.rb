$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../../util/win32")

require 'PortScan'
require 'miq-wmi'
require 'miq-password'

# Ports:
#        Check standard MS ports 135, 139
#
# WMI:
#       Check that we can connect to WMI and verify the HyperV Service

class MSHyperVProbe
	def self.probe(ost)
		if !ost.discover_types.include?(:hyperv) || ost.windows_domain.nil?
			$log.info "Skipping MS Hyper-V Probe" if $log
			return
		end

		$log.info "MSHyperVProbe: probing ip = #{ost.ipaddr}" if $log
    if PortScanner.scanPortArray(ost, [135, 139]).length == 2
      user, pwd = ost.windows_domain
      WMIHelper.connectServer(ost.ipaddr, user, MiqPassword.decrypt(pwd)) do |wmi|
        wmi.run_query("select * from Win32_Service where PathName like '%vmms.exe%' and Started = TRUE") do |svc|
          ost.hypervisor << :hyperv
        end
      end
    end
		$log.info "MSHyperVProbe: probe of ip = #{ost.ipaddr} complete" if $log
	end
end
