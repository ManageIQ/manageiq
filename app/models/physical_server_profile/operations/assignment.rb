module PhysicalServerProfile::Operations::Assignment
  def assign_server(server_id)
    unless ext_management_system
      raise _("Server Profile %{profile} <%{name}> with Id: <%{id}> is not associated with a provider.") %
            {:profile => self, :name => name, :id => id}
    end

    _log.info("Begin assign server with ID: #{server_id} to server profile #{name} (UUID: #{ems_ref})")
    options = {:uuid => ems_ref, :server_id => server_id}
    response = ext_management_system.send(:assign_server, self, options)
    _log.info("Complete assign_server #{self}")
    response
  end

  def deploy_server
    unless ext_management_system
      raise _("Server Profile %{profile} <%{name}> with Id: <%{id}> is not associated with a provider.") %
            {:profile => self, :name => name, :id => id}
    end

    _log.info("Begin deploy of server profile #{name} (UUID: #{ems_ref})")
    options = {:uuid => ems_ref}
    response = ext_management_system.send(:deploy_server, self, options)
    _log.info("Complete deploy_server #{self}")
    response
  end

  def unassign_server
    unless ext_management_system
      raise _("Server Profile %{profile} <%{name}> with Id: <%{id}> is not associated with a provider.") %
            {:profile => self, :name => name, :id => id}
    end

    _log.info("Begin unassign of server profile #{name} (UUID: #{ems_ref})")
    options = {:uuid => ems_ref}
    response = ext_management_system.send(:unassign_server, self, options)
    _log.info("Complete unassign_server #{self}")
    response
  end
end
