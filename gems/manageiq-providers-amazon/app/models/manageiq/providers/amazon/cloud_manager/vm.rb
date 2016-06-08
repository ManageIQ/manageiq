class ManageIQ::Providers::Amazon::CloudManager::Vm < ManageIQ::Providers::CloudManager::Vm
  include_concern 'Operations'

  POWER_STATES = {
    "running"       => "on",
    "powering_up"   => "powering_up",
    "shutting_down" => "powering_down",
    "shutting-down" => "powering_down",
    "stopping"      => "powering_down",
    "pending"       => "suspended",
    "terminated"    => "terminated",
    "stopped"       => "off",
    "off"           => "off",
    # 'unknown' will be set by #disconnect_ems - which means 'terminated' in our case
    "unknown"       => "terminated",
  }.freeze

  has_many :cloud_networks, :through => :cloud_subnets

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
    POWER_STATES[raw_power_state.to_s] || "terminated"
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
