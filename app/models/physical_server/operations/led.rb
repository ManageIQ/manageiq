module PhysicalServer::Operations::Led

  def turn_on_loc_led
    change_state(:turn_on_loc_led)
  end

  def turn_off_loc_led
    change_state(:turn_off_loc_led)
  end

  private
  
  def change_state(verb)
    unless ext_management_system
      raise _("A Server #{self} <%{name}> with Id: <%{id}> is not associated with a provider.") % {:name => name, :id => id}
    end

    options = {:uuid => uuid}
    $lenovo_log.info("Begin #{verb} server: #{name} with UUID: #{uuid}")
    ext_management_system.send(verb, self, options)
    $lenovo_log.info("Complete #{verb} #{self}")
  end

end