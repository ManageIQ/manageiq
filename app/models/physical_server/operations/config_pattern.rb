module PhysicalServer::Operations::ConfigPattern
  def apply_config_pattern(pattern_id)
    change_state(:apply_config_pattern, pattern_id)
  end

  private

  def change_state(verb, pattern_id)
    unless ext_management_system
      raise _("A Server #{self} <%{name}> with Id: <%{id}> is not associated \
with a provider.") % {:name => name, :id => id}
    end

    _log.info("Apply config pattern with ID: #{pattern_id} to server with UUID: #{ems_ref}")

    options = {:uuid => ems_ref, :id => pattern_id, :etype => "rack", :restart => "immediate"}
    response = ext_management_system.send(verb, self, options)

    _log.info("Complete #{verb} #{self}")

    response
  end
end
