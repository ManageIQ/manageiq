module EmsRefresh::SaveInventoryMiddleware
  def save_ems_middleware_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    child_keys = [:middleware_domains, :middleware_servers, :middleware_deployments, :middleware_datasources,
      :middleware_messagings]
    # Save and link other subsections
    child_keys.each do |k|
      send("save_#{k}_inventory", ems, hashes[k], target)
    end

    ems.save!
  end

  def save_middleware_domains_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.middleware_domains(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    save_inventory_multi(ems.middleware_domains, hashes, deletes, [:ems_ref], [:middleware_server_groups])
    store_ids_for_new_records(ems.middleware_domains, hashes, :ems_ref)
  end

  def save_middleware_server_groups_inventory(domain, hashes, target = nil)
    return if hashes.nil?
    target = domain if target.nil?

    domain.middleware_server_groups.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:domain_id] = domain[:id]
    end
    save_inventory_multi(domain.middleware_server_groups, hashes, deletes, [:ems_ref], nil, [:middleware_domain,
                                                                                             :_object])
    store_ids_for_new_records(domain.middleware_server_groups, hashes, :ems_ref)
  end

  def save_middleware_servers_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.middleware_servers(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    hashes.each do |h|
      server_group_id = h.fetch_path(:middleware_server_group, :id)
      if server_group_id.nil?
        nativeid = h.fetch_path(:middleware_server_group, :nativeid)
        feed = h.fetch_path(:feed)
        server_group_id = MiddlewareServerGroup.where('nativeid' => nativeid)
                                               .where('feed' => feed)
                                               .order('created_at')
                                               .try(:last)
                                               .try(:id) unless nativeid.nil?
      end
      h[:server_group_id] = server_group_id unless server_group_id.nil?
    end

    save_inventory_multi(ems.middleware_servers, hashes, deletes, [:ems_ref], nil,
                         [:middleware_server_group])
    store_ids_for_new_records(ems.middleware_servers, hashes, :ems_ref)
  end

  def save_middleware_deployments_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.middleware_deployments(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:server_id] = h.fetch_path(:middleware_server, :id)
      server_group_id = h.fetch_path(:middleware_server, :server_group_id)
      h[:server_group_id] = server_group_id unless server_group_id.nil?
    end

    save_inventory_multi(ems.middleware_deployments, hashes, deletes, [:ems_ref], nil,
                         [:middleware_server])
    store_ids_for_new_records(ems.middleware_deployments, hashes, :ems_ref)
  end

  def save_middleware_datasources_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.middleware_datasources(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:server_id] = h.fetch_path(:middleware_server, :id)
    end

    save_inventory_multi(ems.middleware_datasources, hashes, deletes, [:ems_ref], nil,
                         [:middleware_server])
    store_ids_for_new_records(ems.middleware_datasources, hashes, :ems_ref)
  end

  def save_middleware_messagings_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.middleware_messagings(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:server_id] = h.fetch_path(:middleware_server, :id)
    end

    save_inventory_multi(ems.middleware_messagings, hashes, deletes, [:ems_ref], nil,
                         [:middleware_server])
    store_ids_for_new_records(ems.middleware_messagings, hashes, :ems_ref)
  end
end
