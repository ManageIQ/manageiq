$:.push("#{File.dirname(__FILE__)}/..")

require 'PortScan'

# Ports:
#        5900 - Microsoft Virtual Machine Remote Control Client

class MSScvmmProbe
	def self.probe(ost)
		if !ost.discover_types.include?(:scvmm)
			$log.debug "Skipping MSScvmmProbe" if $log
			return
		end

		$log.debug "MSScvmmProbe: probing ip = #{ost.ipaddr}" if $log
    ost.hypervisor << :scvmm if PortScanner.scanPortArray(ost, [135, 139, 8100]).length == 3
		$log.debug "MSScvmmProbe: probe of ip = #{ost.ipaddr} complete" if $log
	end
end
