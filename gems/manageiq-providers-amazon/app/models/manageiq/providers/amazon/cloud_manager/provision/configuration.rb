module ManageIQ::Providers::Amazon::CloudManager::Provision::Configuration
  def associate_floating_ip(ip_address)
    # TODO(lsmola) this should be moved to FloatingIp model
    destination.with_provider_object do |instance|
      if ip_address.cloud_network_only?
        instance.client.associate_address(:instance_id => instance.instance_id, :allocation_id => ip_address.ems_ref)
      else
        instance.client.associate_address(:instance_id => instance.instance_id, :public_ip => ip_address.address)
      end
    end
  end

  def userdata_payload
    return unless raw_script = super
    Base64.encode64(raw_script)
  end
end
