module PhysicalServer::Operations::Power
  def power_on
    change_state(:power_on)
  end

  def power_off
    change_state(:power_off)
  end

  def power_off_now
    change_state(:power_off_now)
  end

  def restart
    change_state(:restart)
  end

  def restart_now
    change_state(:restart_now)
  end

  def restart_to_sys_setup
    change_state(:restart_to_sys_setup)
  end

  def restart_mgmt_controller
    change_state(:restart_mgmt_controller)
  end
end
