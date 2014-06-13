module MiqHostProvision::Rediscovery
  def find_destination_in_vmdb
    rediscover_host
    host_rediscovered? ? self.host(true) : nil
  end

  def host_rediscovered?
    if pxe_image.try(:pxe_image_type).try(:esx?)
      self.host && self.host.vmm_vendor.to_s.downcase != 'unknown'
    else
      self.state == 'provisioned'
    end
  end

  def rediscover_host
    log_header = "MIQ(#{self.class.name}#rediscover_host)"

    # TODO: why is this check here??
    unless self.state == 'active'
      $log.info "#{log_header} provision task check has already been processed - state: [#{self.state}]"
      return
    end

    $log.info("#{log_header} Refreshing Power State via IPMI")
    self.host.refresh_ipmi_power_state

    $log.info("#{log_header} Rediscovering Host on IP Address: #{ip_address.inspect}")
    discovery_types = []
    discovery_types << :esx if pxe_image.try(:pxe_image_type).try(:esx?)
    self.host.rediscover(ip_address, discovery_types)
  end

end
