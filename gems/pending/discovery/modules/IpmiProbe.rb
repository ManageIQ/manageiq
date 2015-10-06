require 'util/miq-ipmi'

class IpmiProbe
  def self.probe(ost)
    unless ost.discover_types.include?(:ipmi)
      $log.info "Skipping IPMI Probe" if $log
      return
    end

    $log.info "IpmiProbe: probing ip = #{ost.ipaddr}" if $log
    ost.hypervisor << :ipmi if MiqIPMI.is_available?(ost.ipaddr)
    $log.info "IpmiProbe: probe of ip = #{ost.ipaddr} complete" if $log
  end
end
