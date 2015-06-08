module MiqProvisionAmazon::Configuration
  def associate_floating_ip(ip_address)
    destination.with_provider_object do |instance|
      instance.associate_elastic_ip(ip_address)
    end
  end
end
