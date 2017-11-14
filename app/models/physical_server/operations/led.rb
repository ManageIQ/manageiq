module PhysicalServer::Operations::Led
  def blink_loc_led
    change_state(:blink_loc_led)
  end

  def turn_on_loc_led
    change_state(:turn_on_loc_led)
  end

  def turn_off_loc_led
    change_state(:turn_off_loc_led)
  end

  private

  def change_state(verb)
    unless ext_management_system
      raise _("A Server %{server} <%{name}> with Id: <%{id}> is not associated with a provider.") %
            {:server => self, :name => name, :id => id}
    end

    options = {:uuid => ems_ref}
    _log.info("Begin #{verb} server: #{name} with UUID: #{ems_ref}")
    ext_management_system.send(verb, self, options)
    _log.info("Complete #{verb} #{self}")
  end
end
