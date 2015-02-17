module VmOpenstack::Operations::Power
  def validate_stop
    validate_unsupported("Stop Operation")
  end

  def raw_start
    with_provider_connection do |connection|
      case raw_power_state
      when "PAUSED"    then connection.unpause_server(ems_ref)
      when "SUSPENDED" then connection.resume_server(ems_ref)
      when "SHUTDOWN"  then connection.resume_server(ems_ref)
      when "STOPPED"   then connection.start_server(ems_ref)
      end
    end
  end

  def raw_pause
    with_provider_connection { |connection| connection.pause_server(self.ems_ref) }
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "PAUSED")
  end

  def raw_suspend
    with_provider_connection { |connection| connection.suspend_server(self.ems_ref) }
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "SUSPENDED")
  end
end
