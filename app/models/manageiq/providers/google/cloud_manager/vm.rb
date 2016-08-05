class ManageIQ::Providers::Google::CloudManager::Vm < ManageIQ::Providers::CloudManager::Vm
  include_concern 'Operations'

  virtual_column :preemptible?, :type => :boolean, :uses => :advanced_settings

  def preemptible?
    preempt_setting = advanced_settings.detect { |v| v.name == "preemptible?" }

    # It's possible that we got a nil back; this would occur if the VM hasn't
    # been refreshed since this change has been added. If that's the case, log
    # an error and return false for now.
    if preempt_setting.nil?
      _log.warn("Unable to find 'preemptible?' value for vm; this failure is"\
                " likely temporary and will resolve upon a refresh")
      return false
    end

    preempt_setting.value == "true"
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
end
