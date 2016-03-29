class ManageIQ::Providers::Amazon::CloudManager::Vm < ManageIQ::Providers::CloudManager::Vm
  include_concern 'Operations'

  has_many :cloud_networks, :through => :cloud_subnets
  alias_method :private_networks, :cloud_networks
  has_many :cloud_subnets, :through    => :network_ports,
           :class_name => "ManageIQ::Providers::Amazon::NetworkManager::CloudSubnet"
  has_many :public_networks, :through => :cloud_subnets
  has_many :security_groups, :through => :network_ports

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.instance(ems_ref)
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

  def proxies4job(_job = nil)
    {
      :proxies => [MiqServer.my_server],
      :message => 'Perform SmartState Analysis on this VM'
    }
  end

  def disconnected
    false
  end

  def disconnected?
    false
  end

  #
  # EC2 interactions
  #

  def set_custom_field(key, value)
    with_provider_object do |instance|
      tags = instance.create_tags ({
        tags: [
                {
                  key: key,
                  value: value,
                },
              ],
      })
      tags.find{|tag| tag.key == key}.value == value
    end
  end

  def self.calculate_power_state(raw_power_state)
    # http://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_InstanceState.html
    case raw_power_state.to_s
    when "running"       then "on"
    when "powering_up"   then "powering_up"
    when "shutting_down" then "powering_down"
    when "shutting-down" then "powering_down"
    when "stopping"      then "powering_down"
    when "pending"       then "suspended"
    when "terminated"    then "terminated"
    when "stopped"       then "off"
    when "off"           then "off"
    # 'unknown' will be set by #disconnect_ems - which means 'terminated' in our case
    when "unknown"       then "terminated"
    else                      "terminated"
    end
  end

  def validate_migrate
    validate_supported
  end

  def validate_smartstate_analysis
    validate_unsupported("Smartstate Analysis")
  end

  def validate_timeline
    {:available => false,
     :message   => _("Timeline is not available for %{model}") % {:model => ui_lookup(:model => self.class.to_s)}}
  end
end
