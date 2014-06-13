$:.push("#{File.dirname(__FILE__)}/..")

require 'PortScan'

# Ports:
#        902  - VMware Server console
#        912  - VMware Server console

class VMwareServerProbe
	def self.probe(ost)
		if !ost.discover_types.include?(:vmwareserver)
			$log.debug "Skipping VMwareServerProbe" if $log
			return
		end

	  $log.debug "VMwareServerProbe: probing ip = #{ost.ipaddr}" if $log
		ost.hypervisor << :vmwareserver if PortScanner.scanPortArray(ost, [902, 912]).length == 2
		$log.debug "VMwareServerProbe: probe of ip = #{ost.ipaddr} complete" if $log
	end
end
