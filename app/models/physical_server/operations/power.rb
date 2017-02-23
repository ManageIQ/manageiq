module PhysicalServer::Operations::Power
  def power_on
    change_state(:power_on)
  end

  def power_off
    change_state(:power_off)
  end

  def restart
    change_state(:restart)
  end

  private

  def change_state(verb)
    unless ext_management_system
      raise _(" A Server #{self} <%{name}> with Id: <%{id}>
      is not associated with a provider.") % {:name => name, :id => id}
    end
    options = {:uuid => uuid}
    _log.info("Begin #{verb} server: #{name}  with UUID: #{uuid}")
    ext_management_system.send(verb, self, options)
    _log.info("Complete #{verb} #{self}")
  end
end
