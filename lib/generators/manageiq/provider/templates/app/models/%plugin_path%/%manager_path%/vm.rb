class <%= class_name %>::<%= manager_type %>::Vm < ManageIQ::Providers::<%= manager_type %>::Vm
  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    # find vm instance via connection and return it
    # connection.find_instance(ems_ref)
    # but we return just an object for now
    OpenStruct.new
  end

  def raw_start
    with_provider_object(&:start)
    # Temporarily update state for quick UI response until refresh comes along
    update!(:raw_power_state => "on")
  end

  def raw_stop
    with_provider_object(&:stop)
    # Temporarily update state for quick UI response until refresh comes along
    update!(:raw_power_state => "off")
  end

  def raw_pause
    with_provider_object(&:pause)
    # Temporarily update state for quick UI response until refresh comes along
    update!(:raw_power_state => "paused")
  end

  def raw_suspend
    with_provider_object(&:suspend)
    # Temporarily update state for quick UI response until refresh comes along
    update!(:raw_power_state => "suspended")
  end

  # TODO: this method could be the default in a baseclass
  def self.calculate_power_state(raw_power_state)
    # do some mapping on powerstates
    # POWER_STATES[raw_power_state.to_s] || "terminated"
    raw_power_state
  end
end
