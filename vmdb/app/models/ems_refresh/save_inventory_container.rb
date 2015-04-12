module EmsRefresh::SaveInventoryContainer
  def save_ems_container_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    child_keys = [:container_nodes, :container_groups, :container_services,
                  :container_replication_controllers, :container_routes, :container_projects]

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

    save_inventory_multi(:container_routes, ems, hashes, deletes, [:ems_ref],
                         :labels)
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
                         [:computer_system], [:namespace])
    store_ids_for_new_records(ems.container_nodes, hashes, :ems_ref)
  end

  def save_computer_system_inventory(container_node, hash, _target = nil)
    save_inventory_single(:computer_system, container_node, hash, [:hardware])
  end

  def save_container_replication_controllers_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_replication_controllers(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                ems.container_replication_controllers.dup
              else
                []
              end
    save_inventory_multi(:container_replication_controllers, ems, hashes, deletes, [:ems_ref],
                         [:labels, :selector_parts])
    store_ids_for_new_records(ems.container_replication_controllers, hashes, :ems_ref)
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
                         [:labels, :selector_parts], [:container_groups])
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
    end

    save_inventory_multi(:container_groups, ems, hashes, deletes, [:ems_ref],
                         [:container_definitions, :containers, :labels],
                         [:container_node])
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

    save_inventory_multi(:container_definitions, container_group, hashes, deletes, [:ems_ref], :container_port_configs)
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

  def save_containers_inventory(container_group, hashes, target = nil)
    return if hashes.nil?

    container_group.containers(true)
    deletes = if target.kind_of?(ExtManagementSystem)
                container_group.containers.dup
              else
                []
              end

    save_inventory_multi(:containers, container_group, hashes, deletes, [:ems_ref])
    store_ids_for_new_records(container_group.containers, hashes, :ems_ref)
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
