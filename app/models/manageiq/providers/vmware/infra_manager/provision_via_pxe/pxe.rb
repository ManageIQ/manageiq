module ManageIQ::Providers::Vmware::InfraManager::ProvisionViaPxe::Pxe
  def get_mac_address_of_nic_on_requested_vlan
    network_name = get_option(:vlan)
    # Remove the "dvs_" prefix from the vlan name that gets saved as part of the DV switches
    network_name = network_name[4..-1] if network_name[0, 4] == 'dvs_'
    vm = destination
    result = vm.hardware.nics.detect { |n| n.address && n.lan.try(:name) == network_name }.try(:address)
    if result.blank?
      # Sort by device name to control return order.  VMware names nics like: Network adapter 1, Network adapter 2
      nics = vm.hardware.nics.select(&:address).sort_by(&:device_name)
      unless nics.blank?
        mac_addresses = nics.collect { |n| [n.device_name, n.address] }
        _log.info("Vlan lookup did not return a matching MAC address.  Returning first available address from: <#{mac_addresses.inspect}>")
        result = mac_addresses.first.last
      end
    end
    result
  end
end
