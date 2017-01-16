module EmsRefresh::SaveInventoryContainer
  def save_ems_container_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    child_keys = [:container_projects, :container_quotas, :container_limits, :container_nodes,
                  :container_builds, :container_build_pods, :persistent_volume_claims, :persistent_volumes,
                  :container_image_registries, :container_images, :container_replicators, :container_groups,
                  :container_services, :container_routes, :container_component_statuses, :container_templates,
                 ]

    # Save and link other subsections
    child_keys.each do |k|
      send("save_#{k}_inventory", ems, hashes[k], target)
    end

    ems.save!
  end

  def save_container_projects_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_projects.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    save_inventory_multi(ems.container_projects, hashes, deletes, [:ems_ref],
                         [:labels, :tags], [], true)
    store_ids_for_new_records(ems.container_projects, hashes, :ems_ref)
  end

  def save_persistent_volumes_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.persistent_volumes.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:persistent_volume_claim_id] = h.fetch_path(:persistent_volume_claim, :id)
    end

    save_inventory_multi(ems.persistent_volumes, hashes, deletes,
                         [:ems_ref], [], [:persistent_volume_claim, :namespace])
    store_ids_for_new_records(ems.persistent_volumes, hashes, :ems_ref)
  end

  def save_persistent_volume_claims_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.persistent_volume_claims.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    save_inventory_multi(ems.persistent_volume_claims, hashes, deletes,
                         [:ems_ref], [], [:namespace])
    store_ids_for_new_records(ems.persistent_volume_claims, hashes, :ems_ref)
  end

  def save_container_quotas_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_quotas.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:container_project_id] = h.fetch_path(:project, :id)
    end

    save_inventory_multi(ems.container_quotas, hashes, deletes, [:ems_ref], :container_quota_items, :project)
    store_ids_for_new_records(ems.container_quotas, hashes, :ems_ref)
  end

  def save_container_quota_items_inventory(container_quota, hashes, target = nil)
    return if hashes.nil?
    container_quota.container_quota_items.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end
    save_inventory_multi(container_quota.container_quota_items, hashes, deletes, [:resource])
    store_ids_for_new_records(container_quota.container_quota_items, hashes, :resource)
  end

  def save_container_limits_inventory(ems, hashes, target = nil)
    return if hash.nil?
    target = ems if target.nil?

    ems.container_limits.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end
    hashes.each do |h|
      h[:container_project_id] = h.fetch_path(:project, :id)
    end

    save_inventory_multi(ems.container_limits, hashes, deletes, [:ems_ref], :container_limit_items, :project)
    store_ids_for_new_records(ems.container_limits, hashes, :ems_ref)
  end

  def save_container_limit_items_inventory(container_limit, hashes, target = nil)
    return if hashes.nil?
    container_limit.container_limit_items.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end
    save_inventory_multi(container_limit.container_limit_items, hashes, deletes, [:resource, :item_type])
    store_ids_for_new_records(container_limit.container_limit_items, hashes, [:resource, :item_type])
  end

  def save_container_routes_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_routes.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:container_project_id] = h.fetch_path(:project, :id)
      h[:container_service_id] = h.fetch_path(:container_service, :id)
    end

    save_inventory_multi(ems.container_routes, hashes, deletes, [:ems_ref],
                         [:labels, :tags], [:container_service, :project, :namespace])
    store_ids_for_new_records(ems.container_routes, hashes, :ems_ref)
  end

  def save_container_nodes_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_nodes.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    save_inventory_multi(ems.container_nodes, hashes, deletes, [:ems_ref],
                         [:labels, :tags, :computer_system, :container_conditions], [:namespace])
    store_ids_for_new_records(ems.container_nodes, hashes, :ems_ref)
  end

  def save_computer_system_inventory(container_node, hash, _target = nil)
    save_inventory_single(:computer_system, container_node, hash, [:hardware, :operating_system])
  end

  def save_container_replicators_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_replicators.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:container_project_id] = h.fetch_path(:project, :id)
    end

    save_inventory_multi(ems.container_replicators, hashes, deletes, [:ems_ref],
                         [:labels, :tags, :selector_parts], [:project, :namespace])
    store_ids_for_new_records(ems.container_replicators, hashes, :ems_ref)
  end

  def save_container_services_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_services.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:container_group_ids] = h[:container_groups].map { |x| x[:id] }
      h[:container_project_id] = h.fetch_path(:project, :id)
      h[:container_image_registry_id] = h.fetch_path(:container_image_registry, :id)
    end

    save_inventory_multi(ems.container_services, hashes, deletes, [:ems_ref],
                         [:labels, :tags, :selector_parts, :container_service_port_configs],
                         [:container_groups, :project, :container_image_registry, :namespace])

    store_ids_for_new_records(ems.container_services, hashes, :ems_ref)
  end

  def save_container_groups_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_groups.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:container_node_id] = h.fetch_path(:container_node, :id)
      h[:container_replicator_id] = h.fetch_path(:container_replicator, :id)
      h[:container_project_id] = h.fetch_path(:project, :id)
      h[:container_build_pod_id] = ems.container_build_pods.find_by(:name => 
        h[:build_pod_name]).try(:id)
    end

    save_inventory_multi(ems.container_groups, hashes, deletes, [:ems_ref],
                         [:container_definitions, :containers, :labels, :tags,
                          :node_selector_parts, :container_conditions, :container_volumes],
                         [:container_node, :container_replicator, :project, :namespace, :build_pod_name],
                         true)
    store_ids_for_new_records(ems.container_groups, hashes, :ems_ref)
  end

  def save_container_definitions_inventory(container_group, hashes, target = nil)
    return if hashes.nil?

    container_group.container_definitions.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:ems_id] = container_group[:ems_id]
    end

    save_inventory_multi(container_group.container_definitions, hashes, deletes, [:ems_ref],
                         [:container_port_configs, :container_env_vars, :security_context, :container],
                         [], true)
    store_ids_for_new_records(container_group.container_definitions, hashes, :ems_ref)
  end

  def save_container_port_configs_inventory(container_definition, hashes, target = nil)
    return if hashes.nil?

    container_definition.container_port_configs.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    save_inventory_multi(container_definition.container_port_configs, hashes, deletes, [:ems_ref])
    store_ids_for_new_records(container_definition.container_port_configs, hashes, :ems_ref)
  end

  def save_container_service_port_configs_inventory(container_service, hashes, target = nil)
    return if hashes.nil?

    container_service.container_service_port_configs.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    save_inventory_multi(container_service.container_service_port_configs, hashes, deletes, [:ems_ref])
    store_ids_for_new_records(container_service.container_service_port_configs, hashes, :ems_ref)
  end

  def save_container_env_vars_inventory(container_definition, hashes, target = nil)
    return if hashes.nil?
    container_definition.container_env_vars.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end
    save_inventory_multi(container_definition.container_env_vars, hashes, deletes, [:name, :value, :field_path])
    store_ids_for_new_records(container_definition.container_env_vars, hashes, [:name, :value, :field_path])
  end

  def save_container_images_inventory(ems, hashes, target = nil)
    return if hashes.nil?

    ems.container_images.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:container_image_registry_id] = h[:container_image_registry][:id] unless h[:container_image_registry].nil?
    end

    save_inventory_multi(ems.container_images, hashes, deletes, [:image_ref, :container_image_registry_id],
                         [:labels, :docker_labels], :container_image_registry, true)
    store_ids_for_new_records(ems.container_images, hashes,
                              [:image_ref, :container_image_registry_id])
  end

  def save_container_image_registries_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_image_registries.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    save_inventory_multi(ems.container_image_registries, hashes, deletes, [:host, :port])
    store_ids_for_new_records(ems.container_image_registries, hashes, [:host, :port])
  end

  def save_container_component_statuses_inventory(ems, hashes, target = nil)
    return if hashes.nil?

    ems.container_component_statuses.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    save_inventory_multi(ems.container_component_statuses, hashes, deletes, [:name])
    store_ids_for_new_records(ems.container_component_statuses, hashes, :name)
  end

  def save_container_inventory(container_definition, hash, _target = nil)
    # The hash could be nil when the container is in transition (still downloading
    # the image, or stuck in Pending, or unable to fetch the image). Passing nil to
    # save_inventory_single is used to delete any pre-existing entity in containers,
    hash[:container_image_id] = hash[:container_image][:id] unless hash.nil?
    hash[:ems_id] = container_definition[:ems_id] unless hash.nil?
    save_inventory_single(:container, container_definition, hash, [], :container_image, true)
  end

  def save_container_conditions_inventory(container_entity, hashes, target = nil)
    return if hashes.nil?

    container_entity.container_conditions.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    save_inventory_multi(container_entity.container_conditions, hashes, deletes, [:name])
    store_ids_for_new_records(container_entity.container_conditions, hashes, :name)
  end

  def save_security_context_inventory(container_definition, hash, _target = nil)
    save_inventory_single(:security_context, container_definition, hash)
  end

  def save_container_volumes_inventory(container_group, hashes, target = nil)
    return if hashes.nil?

    container_group.container_volumes.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:persistent_volume_claim_id] = h.fetch_path(:persistent_volume_claim, :id)
    end

    save_inventory_multi(container_group.container_volumes, hashes, deletes, [:name], [], [:persistent_volume_claim])
    store_ids_for_new_records(container_group.container_volumes, hashes, :name)
  end

  def save_custom_attribute_attribute_inventory(entity, attribute_name, hashes, target = nil)
    return if hashes.nil?

    entity.send(attribute_name).reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    save_inventory_multi(entity.send(attribute_name),
                         hashes, deletes, [:section, :name])
    store_ids_for_new_records(entity.send(attribute_name),
                              hashes, [:section, :name])
  end

  def save_labels_inventory(entity, hashes, target = nil)
    save_custom_attribute_attribute_inventory(entity, :labels, hashes, target)
  end

  def save_docker_labels_inventory(entity, hashes, target = nil)
    save_custom_attribute_attribute_inventory(entity, :docker_labels, hashes, target)
  end

  def save_tags_inventory(entity, hashes, _target = nil)
    return if hashes.nil?

    ContainerLabelTagMapping.retag_entity(entity, hashes) # Keeps user-assigned tags.
  rescue => err
    raise if EmsRefresh.debug_failures
    _log.error("Auto-tagging failed on #{entity.class} [#{entity.name}] with error [#{err}].")
    _log.log_backtrace(err)
  end

  def save_selector_parts_inventory(entity, hashes, target = nil)
    return if hashes.nil?

    entity.selector_parts.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    save_inventory_multi(entity.selector_parts, hashes, deletes, [:section, :name])
    store_ids_for_new_records(entity.selector_parts, hashes, [:section, :name])
  end

  def save_node_selector_parts_inventory(entity, hashes, target = nil)
    return if hashes.nil?

    entity.node_selector_parts.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    save_inventory_multi(entity.node_selector_parts, hashes, deletes, [:section, :name])
    store_ids_for_new_records(entity.node_selector_parts, hashes, [:section, :name])
  end

  def save_container_builds_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_builds.reset
    deletes = target.kind_of?(ExtManagementSystem) ? :use_association : []

    hashes.each do |h|
      h[:container_project_id] = h.fetch_path(:project, :id)
    end
    save_inventory_multi(ems.container_builds, hashes, deletes, [:ems_ref], [:labels, :tags],
                         [:project, :resources])
    store_ids_for_new_records(ems.container_builds, hashes, :ems_ref)
  end

  def save_container_build_pods_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_build_pods.reset
    deletes = target.kind_of?(ExtManagementSystem) ? :use_association : []

    hashes.each do |h|
      h[:container_build_id] = h.fetch_path(:build_config, :id)
    end

    save_inventory_multi(ems.container_build_pods, hashes, deletes, [:ems_ref], [:labels,],
                         [:build_config])
    store_ids_for_new_records(ems.container_build_pods, hashes, :ems_ref)
  end

  def save_container_templates_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.container_templates.reset
    deletes = target.kind_of?(ExtManagementSystem) ? :use_association : []

    hashes.each do |h|
      h[:container_project_id] = h.fetch_path(:container_project, :id)
    end

    save_inventory_multi(ems.container_templates, hashes, deletes, [:ems_ref],
                         [:container_template_parameters, :labels], [:container_project, :namespace])
    store_ids_for_new_records(ems.container_templates, hashes, :ems_ref)
  end

  def save_container_template_parameters_inventory(container_template, hashes, target = nil)
    return if hashes.nil?

    container_template.container_template_parameters.reset
    deletes = target.kind_of?(ExtManagementSystem) ? :use_association : []

    save_inventory_multi(container_template.container_template_parameters, hashes, deletes, [:name], [], [])
    store_ids_for_new_records(container_template.container_template_parameters, hashes, :name)
  end
end
