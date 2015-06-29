$:.push("#{File.dirname(__FILE__)}/..")
require 'PortScan'

class RedHatRhevmProbe
  def self.probe(ost)
    log_header = "RedHatRhevmProbe"
    unless ost.discover_types.include?(:rhevm)
      $log.debug "Skipping #{log_header}" if $log
      return
    end

    $log.debug "#{log_header}: probing ip = #{ost.ipaddr}" if $log

    require 'ovirt'
    if PortScanner.portOpen(ost, Ovirt::Service::DEFAULT_PORT)
      if Ovirt::Service.ovirt?(:server => ost.ipaddr, :verify_ssl => false)
        ost.hypervisor << :rhevm
      end
    end
    $log.debug "#{log_header}: probe of ip = #{ost.ipaddr} complete" if $log
  end
end
