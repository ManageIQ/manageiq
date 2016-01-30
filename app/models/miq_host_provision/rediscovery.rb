module MiqHostProvision::Rediscovery
  def find_destination_in_vmdb
    rediscover_host
    host_rediscovered? ? host(true) : nil
  end

  def host_rediscovered?
    if pxe_image.try(:pxe_image_type).try(:esx?)
      host && host.vmm_vendor.to_s.downcase != 'unknown'
    else
      state == 'provisioned'
    end
  end

  def rediscover_host
    # TODO: why is this check here??
    unless state == 'active'
      _log.info "provision task check has already been processed - state: [#{state}]"
      return
    end

    _log.info("Refreshing Power State via IPMI")
    host.refresh_ipmi_power_state

    _log.info("Rediscovering Host on IP Address: #{ip_address.inspect}")
    discovery_types = []
    discovery_types << :esx if pxe_image.try(:pxe_image_type).try(:esx?)
    host.rediscover(ip_address, discovery_types)
  end
end
