module VmOpenstack::Operations::Power
  def validate_stop
    validate_unsupported("Stop Operation")
  end

  def raw_start
    with_provider_connection { |connection| connection.unpause_server(self.ems_ref) }
  end

  def raw_pause
    with_provider_connection { |connection| connection.pause_server(self.ems_ref) }
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:state => "suspended")
  end

  def raw_suspend
    with_provider_connection { |connection| connection.suspend_server(self.ems_ref) }
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:state => "suspended")
  end
end
