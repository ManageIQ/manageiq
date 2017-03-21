module ManageIQ::Providers::Openstack::CloudManager::Vm::Operations::Power
  def validate_shelve
    validate_vm_control_shelve_action
  end

  def validate_shelve_offload
    validate_vm_control_shelve_offload_action
  end

  def raw_start
    with_provider_connection do |connection|
      case raw_power_state
      when "PAUSED"                       then connection.unpause_server(ems_ref)
      when "SUSPENDED"                    then connection.resume_server(ems_ref)
      when "SHUTOFF"                      then connection.start_server(ems_ref)
      when "SHELVED", "SHELVED_OFFLOADED" then connection.unshelve_server(ems_ref)
      end
    end
    self.update_attributes!(:raw_power_state => "ACTIVE")
  end

  def raw_stop
    with_provider_connection { |connection| connection.stop_server(ems_ref) }
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "SHUTOFF")
  end

  def raw_pause
    with_provider_connection { |connection| connection.pause_server(ems_ref) }
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "PAUSED")
  end

  def raw_suspend
    with_provider_connection { |connection| connection.suspend_server(ems_ref) }
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "SUSPENDED")
  end

  def raw_shelve
    with_provider_connection { |connection| connection.shelve_server(ems_ref) }
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "SHELVED")
  end

  def raw_shelve_offload
    with_provider_connection { |connection| connection.shelve_offload_server(ems_ref) }
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "SHELVED_OFFLOADED")
  end
end
