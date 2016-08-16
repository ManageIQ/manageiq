require 'discovery/port_scanner'

# Ports:
#        5900 - Microsoft Virtual Machine Remote Control Client

class MSVirtualServerProbe
  def self.probe(ost)
    unless ost.discover_types.include?(:msvirtualserver)
      $log.debug "Skipping MSVirtualServerProbe" if $log
      return
    end

    $log.debug "MSVirtualServerProbe: probing ip = #{ost.ipaddr}" if $log
    ost.hypervisor << :msvirtualserver if PortScanner.portOpen(ost, "5900")
    $log.debug "MSVirtualServerProbe: probe of ip = #{ost.ipaddr} complete" if $log
  end
end
