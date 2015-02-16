module EmsRefresh::SaveInventoryContainer
  def save_ems_container_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    child_keys = [:container_nodes, :container_services, :container_groups]
    # Save and link other subsections
    child_keys.each do |k|
      send("save_#{k}_inventory", ems, hashes[k], target)
    end

    ems.save!
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

    save_inventory_multi(:container_nodes, ems, hashes, deletes, :ems_ref)
    store_ids_for_new_records(ems.container_nodes, hashes, :ems_ref)
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

    save_inventory_multi(:container_services, ems, hashes, deletes, :ems_ref, [:labels])
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

    save_inventory_multi(:container_groups, ems, hashes, deletes, :ems_ref, [:container_definitions, :containers, :labels])
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

    save_inventory_multi(:container_definitions, container_group, hashes, deletes, :ems_ref, :container_port_configs)
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

    save_inventory_multi(:container_port_configs, container_definition, hashes, deletes, :ems_ref)
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

    save_inventory_multi(:containers, container_group, hashes, deletes, :ems_ref)
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
end
