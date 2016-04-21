class ManageIQ::Providers::Azure::CloudManager::Vm < ManageIQ::Providers::CloudManager::Vm
  include_concern 'Operations'
  include_concern 'ManageIQ::Providers::Azure::CloudManager::VmOrTemplateShared'

  has_many :cloud_networks, :through => :cloud_subnets
  has_many :security_groups, :through => :network_ports

  def cloud_network
    # TODO(lsmola) NetworkProvider Backwards compatibility layer with simplified architecture where VM has only one
    # network. Put this into ManageIQ::Providers::CloudManager::Vm when NetworkProvider is done in all providers
    cloud_networks.first
  end

  def cloud_subnet
    # TODO(lsmola) NetworkProvider Backwards compatibility layer with simplified architecture where VM has only one
    # network. Put this into ManageIQ::Providers::CloudManager::Vm when NetworkProvider is done in all providers
    cloud_subnets.first
  end

  def provider_service(connection = nil)
    connection ||= ext_management_system.connect
    ::Azure::Armrest::VirtualMachineService.new(connection)
  end

  # The resource group is stored as part of the uid_ems. This splits it out.
  def resource_group
    uid_ems.split('\\')[1]
  end

  #
  # Relationship methods
  #

  def disconnect_inv
    super

    # Mark all instances no longer found as unknown
    self.raw_power_state = "unknown"
    save
  end

  def disconnected
    false
  end

  def disconnected?
    false
  end

  def self.calculate_power_state(raw_power_state)
    case raw_power_state.downcase
    when /running/, /starting/
      "on"
    when /stopped/, /stopping/
      "suspended"
    when /dealloc/
      "off"
    else
      "unknown"
    end
  end
end
