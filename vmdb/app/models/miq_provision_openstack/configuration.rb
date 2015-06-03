module MiqProvisionOpenstack::Configuration
  def associate_floating_ip(ip_address)
    destination.with_provider_object do |instance|
      instance.associate_address(ip_address)
    end
  end

  def configure_network_adapters
    @nics ||= begin
      networks = Array(options[:networks])

      # Set the first nic to whatever was selected in the dialog if not set by automate
      networks[0] ||= {:network_id => cloud_network.id} if cloud_network

      options[:networks] = convert_networks_to_openstack_nics(networks)
    end
  end

  private

  def convert_networks_to_openstack_nics(networks)
    networks.delete_blanks.collect { |nic| {"net_id" => CloudNetwork.where(:id => nic[:network_id]).first.ems_ref} }
  end
end
