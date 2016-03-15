class ManageIQ::Providers::Amazon::CloudManager::Vm < ManageIQ::Providers::CloudManager::Vm
  include_concern 'Operations'

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.instance(ems_ref)
  end

  #
  # Relationship methods
  #

  def disconnect_inv
    super

    # Mark all instances no longer found as terminated
    power_state == "off"
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
    case raw_power_state
    when "running"       then "on"
    when "powering_up"   then "powering_up"
    when "shutting_down" then "powering_down"
    when "pending"       then "suspended"
    when "terminated"    then "terminated"
    else                      "off"
    end
  end

  def validate_migrate
    validate_supported
  end

  def validate_smartstate_analysis
    validate_unsupported("Smartstate Analysis")
  end
end
