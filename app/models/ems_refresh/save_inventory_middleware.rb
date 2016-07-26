module EmsRefresh::SaveInventoryMiddleware
  def save_ems_middleware_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    child_keys = [:middleware_domains, :middleware_server_groups, :middleware_servers, :middleware_deployments,
                  :middleware_datasources]
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

    save_inventory_multi(ems.middleware_domains, hashes, deletes, [:ems_ref])
    store_ids_for_new_records(ems.middleware_domains, hashes, :ems_ref)
  end

  def save_middleware_server_groups_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.middleware_server_groups(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:domain_id] = h.fetch_path(:middleware_domain, :id)
    end

    save_inventory_multi(ems.middleware_server_groups, hashes, deletes, [:ems_ref], nil,
                         [:middleware_domain])
    store_ids_for_new_records(ems.middleware_server_groups, hashes, :ems_ref)
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
      h[:server_group_id] = h.fetch_path(:middleware_server_group, :id)
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
end
