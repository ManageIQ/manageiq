module EmsRefresh::SaveInventoryContainer
  def save_ems_container_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    child_keys = [:container_nodes, :container_replicators, :container_groups,
                  :container_services, :container_routes, :container_projects]

    # Save and link other subsections
    child_keys.each do |k|
      send("save_#{k}_inventory", ems, hashes[k], target)
    end

    ems.save!
  end

  def save_container_projects_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_projects(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                ems.container_projects.dup
              else
                []
              end

    save_inventory_multi(:container_projects, ems, hashes, deletes, [:ems_ref],
                         :labels)
    store_ids_for_new_records(ems.container_projects, hashes, :ems_ref)
  end

  def save_container_routes_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_routes(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                ems.container_routes.dup
              else
                []
              end

    hashes.each do |h|
      h[:container_service_id] = h.fetch_path(:container_service, :id)
    end

    save_inventory_multi(:container_routes, ems, hashes, deletes, [:ems_ref],
                         :labels, :container_service)
    store_ids_for_new_records(ems.container_routes, hashes, :ems_ref)
  end

  def save_container_nodes_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_nodes(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                ems.container_nodes.dup
              else
                []
              end

    save_inventory_multi(:container_nodes, ems, hashes, deletes, [:ems_ref],
                         [:computer_system, :container_node_conditions], [:namespace])
    store_ids_for_new_records(ems.container_nodes, hashes, :ems_ref)
  end

  def save_computer_system_inventory(container_node, hash, _target = nil)
    save_inventory_single(:computer_system, container_node, hash, [:hardware, :operating_system])
  end

  def save_container_replicators_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_replicators(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                ems.container_replicators.dup
              else
                []
              end
    save_inventory_multi(:container_replicators, ems, hashes, deletes, [:ems_ref],
                         [:labels, :selector_parts])
    store_ids_for_new_records(ems.container_replicators, hashes, :ems_ref)
  end

  def save_container_services_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_services(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                ems.container_services.dup
              else
                []
              end

    hashes.each do |h|
      h[:container_group_ids] = h[:container_groups].map { |x| x[:id] }
    end

    save_inventory_multi(:container_services, ems, hashes, deletes, [:ems_ref],
                         [:labels, :selector_parts, :container_service_port_configs], [:container_groups])

    store_ids_for_new_records(ems.container_services, hashes, :ems_ref)
  end

  def save_container_groups_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_groups(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                ems.container_groups.dup
              else
                []
              end

    hashes.each do |h|
      h[:container_node_id] = h.fetch_path(:container_node, :id)
      h[:container_replicator_id] = h.fetch_path(:container_replicator, :id)
    end

    save_inventory_multi(:container_groups, ems, hashes, deletes, [:ems_ref],
                         [:container_definitions, :labels],
                         [:container_node, :container_replicator])
    store_ids_for_new_records(ems.container_groups, hashes, :ems_ref)
  end

  def save_container_definitions_inventory(container_group, hashes, target = nil)
    return if hashes.nil?

    container_group.container_definitions(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                container_group.container_definitions.dup
              else
                []
              end

    save_inventory_multi(:container_definitions, container_group, hashes, deletes,
                         [:ems_ref], [:container_port_configs, :container])
    store_ids_for_new_records(container_group.container_definitions, hashes, :ems_ref)
  end

  def save_container_port_configs_inventory(container_definition, hashes, target = nil)
    return if hashes.nil?

    container_definition.container_port_configs(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                container_definition.container_port_configs.dup
              else
                []
              end

    save_inventory_multi(:container_port_configs, container_definition, hashes, deletes, [:ems_ref])
    store_ids_for_new_records(container_definition.container_port_configs, hashes, :ems_ref)
  end

  def save_container_service_port_configs_inventory(container_service, hashes, target = nil)
    return if hashes.nil?

    container_service.container_service_port_configs(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                container_service.container_service_port_configs.dup
              else
                []
              end

    save_inventory_multi(:container_service_port_configs, container_service, hashes, deletes, [:ems_ref])
    store_ids_for_new_records(container_service.container_service_port_configs, hashes, :ems_ref)
  end

  def save_container_inventory(container_definition, hash, _target = nil)
    hash[:container_group_id] = container_definition.container_group_id
    save_inventory_single(:container, container_definition, hash)
  end

  def save_container_node_conditions_inventory(container_node, hashes, target = nil)
    return if hashes.nil?

    container_node.container_node_conditions(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                container_node.container_node_conditions.dup
              else
                []
              end

    save_inventory_multi(:container_node_conditions, container_node, hashes, deletes, [:name])
    store_ids_for_new_records(container_node.container_node_conditions, hashes, :name)
  end

  def save_labels_inventory(entity, hashes, target = nil)
    return if hashes.nil?

    entity.labels(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                entity.labels.dup
              else
                []
              end

    save_inventory_multi(:labels, entity, hashes, deletes, [:section, :name])
    store_ids_for_new_records(entity.labels, hashes, [:section, :name])
  end

  def save_selector_parts_inventory(entity, hashes, target = nil)
    return if hashes.nil?

    entity.selector_parts(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                entity.selector_parts.dup
              else
                []
              end

    save_inventory_multi(:selector_parts, entity, hashes, deletes, [:section, :name])
    store_ids_for_new_records(entity.selector_parts, hashes, [:section, :name])
  end
end
