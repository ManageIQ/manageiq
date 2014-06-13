$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../../RedHatEnterpriseVirtualizationManagerAPI")
require 'PortScan'

class RedHatRhevmProbe
    
	def self.probe(ost)
    log_header = "RedHatRhevmProbe"
		unless ost.discover_types.include?(:rhevm)
			$log.debug "Skipping #{log_header}" if $log
			return
		end

		$log.debug "#{log_header}: probing ip = #{ost.ipaddr}" if $log

    require 'rhevm_inventory'    

    if PortScanner.portOpen(ost, RhevmService::DEFAULT_PORT)
      begin
        rhevm = RhevmInventory.new(
                      :server   => ost.ipaddr,
                      :username => 'test',
                      :password => 'test')
        rhevm.api
      rescue => err
        ost.hypervisor << :rhevm if err.to_s.include?('401 Unauthorized:')
      end
    end
		$log.debug "#{log_header}: probe of ip = #{ost.ipaddr} complete" if $log

	end
	
end # class VMwareEsxVcProbe
