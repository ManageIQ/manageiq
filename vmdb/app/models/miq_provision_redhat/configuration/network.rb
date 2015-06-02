module MiqProvisionRedhat::Configuration::Network
  def configure_network_adapters
    configure_dialog_nic
    requested_vnics   = options[:networks]

    if requested_vnics.nil?
      $log.info "MIQ(#{self.class.name}#configure_network_adapters) NIC settings will be inherited from the template."
      return
    end

    requested_vnics.stretch!(destination_vnics).each_with_index do |requested_vnic, idx|
      if requested_vnic.nil?
        # Remove any unneeded vm nics
        destination_vnics[idx].destroy
      else
        # Create or update existing nics
        configure_vnic(requested_vnic, "nic#{idx + 1}", destination_vnics[idx])
      end
    end
  end

  # TODO: Move this into EMS Refresh
  def get_mac_address_of_nic_on_requested_vlan
    network = find_network_in_cluster(get_option(:vlan))
    return nil if network.nil?

    nic = find_nic_on_network(network)
    return nil if nic.nil?

    nic[:mac][:address]
  end

  private

  def destination_vnics
    # Nics are not always ordered in the XML response
    @destination_vnics ||= get_provider_destination.nics.sort_by { |n| n[:name] }
  end

  def find_network_in_cluster(network_name)
    network = self.source.with_provider_connection do |rhevm|
      Ovirt::Cluster.find_by_href(rhevm, dest_cluster.ems_ref).try(:find_network_by_name, network_name)
    end

    $log.warn "MIQ(#{self.class.name}#find_network_in_cluster) Cannot find network name=#{network_name}" if network.nil?
    network
  end

  def find_nic_on_network(network)
    nic = get_provider_destination.nics.detect { |n| n[:network][:id] == network[:id] }

    $log.warn "MIQ(#{self.class.name}#find_nic_on_network) Cannot find NIC with network id=#{network[:id].inspect}" if nic.nil?
    nic
  end

  def configure_dialog_nic
    vlan = get_option(:vlan)
    return if vlan.blank?
    options[:networks]    ||= []
    options[:networks][0] ||= begin
      $log.info("MIQ(#{self.class.name}.configure_dialog_nic) vlan: #{vlan.inspect}")
      {:network => vlan, :mac_address => get_option_last(:mac_address)}
    end
  end

  def configure_vnic(network_hash, name, vnic)
    mac_addr  = network_hash[:mac_address]
    network   = find_network_in_cluster(network_hash[:network])
    raise MiqException::MiqProvisionError, "Unable to find specified network: <#{network_hash[:network]}>" if network.nil?

    options = {
      :name        => name,
      :interface   => network_hash[:interface],
      :network_id  => network[:id],
      :mac_address => mac_addr,
    }.delete_blanks

    $log.info("MIQ(#{self.class.name}.configure_vnic) with options: <#{options.inspect}>")

    vnic.nil? ? get_provider_destination.create_nic(options) : vnic.apply_options!(options)
  end
end
