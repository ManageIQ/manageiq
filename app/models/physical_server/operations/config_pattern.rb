module PhysicalServer::Operations::ConfigPattern
  def apply_config_pattern(pattern_id)
    unless ext_management_system
      raise _("A Server %{server} <%{name}> with Id: <%{id}> is not associated with a provider.") %
            {:server => self, :name => name, :id => id}
    end

    _log.info("Apply config pattern with ID: #{pattern_id} to server with UUID: #{ems_ref}")

    options = {:uuid => ems_ref, :id => pattern_id, :etype => "rack", :restart => "immediate"}
    response = ext_management_system.send(:apply_config_pattern, self, options)

    _log.info("Complete apply_config_pattern #{self}")

    response
  end
end
