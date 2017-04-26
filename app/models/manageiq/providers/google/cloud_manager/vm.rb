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

    # Mark all instances no longer found as missing
    self.raw_power_state = "_missing"
    save
  end

  def disconnected
    false
  end

  def disconnected?
    false
  end

  def self.calculate_power_state(raw_power_state)
    # See https://cloud.google.com/compute/docs/reference/latest/instances#resource
    # for possible power states. A good description of the states is available
    # here:
    # https://cloud.google.com/compute/docs/instances/checking-instance-status
    case raw_power_state
    when "PROVISIONING" then "wait_for_launch"
    when "STAGING"      then "wait_for_launch"
    when "RUNNING"      then "on"
    when "STOPPING"     then "off"
    when "SUSPENDED"    then "suspended"
    when "SUSPENDING"   then "suspended"
    when "TERMINATED"   then "off" # confusingly GCE refers to instances that are stopped as "terminated"
    when "_missing"     then "terminated" # special value added by #disconnect_inv
    else "unknown"
    end
  end
end
