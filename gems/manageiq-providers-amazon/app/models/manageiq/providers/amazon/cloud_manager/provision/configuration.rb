module ManageIQ::Providers::Amazon::CloudManager::Provision::Configuration
  def associate_floating_ip(ip_address)
    destination.with_provider_object do |instance|
      instance.client.associate_address(:instance_id => instance.instance_id, :public_ip => ip_address)
    end
  end

  def userdata_payload
    return unless raw_script = super
    Base64.encode64(raw_script)
  end
end
