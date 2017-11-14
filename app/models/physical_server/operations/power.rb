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

  private

  def change_state(verb)
    unless ext_management_system
      raise _(" A Server %{server} <%{name}> with Id: <%{id}> is not associated with a provider.") %
            {:server => self, :name => name, :id => id}
    end
    options = {:uuid => ems_ref}
    _log.info("Begin #{verb} server: #{name}  with UUID: #{ems_ref}")
    ext_management_system.send(verb, self, options)
    _log.info("Complete #{verb} #{self}")
  end
end
