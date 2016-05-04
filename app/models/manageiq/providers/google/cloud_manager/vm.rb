class ManageIQ::Providers::Google::CloudManager::Vm < ManageIQ::Providers::CloudManager::Vm
  include_concern 'Operations'

  has_and_belongs_to_many :security_groups, :join_table => :security_groups_vms, :foreign_key => :vm_id

  # TODO(NetworkManager) ipaddresses and mac_addresses will go away when we will rewrite google to have NetworkManager
  virtual_column :ipaddresses,   :type => :string_set, :uses => {:hardware => :ipaddresses}
  virtual_column :mac_addresses, :type => :string_set, :uses => {:hardware => :mac_addresses}
  def ipaddresses
    hardware.nil? ? [] : hardware.ipaddresses
  end

  def mac_addresses
    hardware.nil? ? [] : hardware.mac_addresses
  end

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.servers.get(name, availability_zone.name)
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
    when /terminated/, /stopping/
      "off"
    else
      "unknown"
    end
  end

  def validate_smartstate_analysis
    validate_unsupported("Smartstate Analysis")
  end
end
