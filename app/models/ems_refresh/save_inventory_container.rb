module EmsRefresh::SaveInventoryContainer
  def save_ems_container_inventory(ems, hashes, _target = nil)
    InventoryRefresh::SaveInventory.save_inventory(ems, [hashes[:tag_mapper].tags_to_resolve_collection])

    child_keys = [:container_projects, :container_quotas, :container_limits, :container_nodes,
                  :container_builds, :container_build_pods, :persistent_volume_claims, :persistent_volumes,
                  :container_image_registries, :container_images, :container_replicators, :container_groups,
                  :container_services, :container_routes, :container_templates,]

    # Save and link other subsections
    child_keys.each do |k|
      send("save_#{k}_inventory", ems, hashes[k])
    end

    ems.save!
  end

  def save_container_projects_inventory(ems, hashes)
    return if hashes.nil?

    ems.container_projects.reset

    save_inventory_multi(ems.container_projects, hashes, :use_association, [:ems_ref],
                         [:labels, :tags], [], true)
    store_ids_for_new_records(ems.container_projects, hashes, :ems_ref)
  end

  def save_persistent_volumes_inventory(ems, hashes)
    return if hashes.nil?

    ems.persistent_volumes.reset

    hashes.each do |h|
      h[:persistent_volume_claim_id] = h.fetch_path(:persistent_volume_claim, :id)
    end

    save_inventory_multi(ems.persistent_volumes, hashes, :use_association,
                         [:ems_ref], [], [:persistent_volume_claim, :namespace])
    store_ids_for_new_records(ems.persistent_volumes, hashes, :ems_ref)
  end

  def save_persistent_volume_claims_inventory(ems, hashes)
    return if hashes.nil?

    ems.persistent_volume_claims.reset
    hashes.each do |h|
      h[:container_project_id] = h.delete_path(:project)[:id]
    end

    save_inventory_multi(ems.persistent_volume_claims, hashes, :use_association,
                         [:ems_ref], [], [:namespace])
    store_ids_for_new_records(ems.persistent_volume_claims, hashes, :ems_ref)
  end

  def save_container_quotas_inventory(ems, hashes)
    return if hashes.nil?

    ems.container_quotas.reset

    hashes.each do |h|
      h[:container_project_id] = h.fetch_path(:project, :id)
    end

    save_inventory_multi(ems.container_quotas, hashes, :use_association,
                         [:ems_ref], [:container_quota_items, :container_quota_scopes], :project,
                         true)
    store_ids_for_new_records(ems.container_quotas, hashes, :ems_ref)
  end

  def save_container_quota_scopes_inventory(container_quota, hashes)
    return if hashes.nil?
    container_quota.container_quota_scopes.reset

    save_inventory_multi(container_quota.container_quota_scopes, hashes, :use_association, [:scope])
    store_ids_for_new_records(container_quota.container_quota_scopes, hashes, :scope)
  end

  def save_container_quota_items_inventory(container_quota, hashes)
    return if hashes.nil?
    container_quota.container_quota_items.reset

    # Archive and create new on changes, not only on deletion - by including the data in find_key.
    save_inventory_multi(container_quota.container_quota_items, hashes, :use_association,
                         [:resource, :quota_desired, :quota_enforced, :quota_observed], [], [],
                         true)
    store_ids_for_new_records(container_quota.container_quota_items, hashes, :resource)
  end

  def save_container_limits_inventory(ems, hashes)
    return if hash.nil?

    ems.container_limits.reset

    hashes.each do |h|
      h[:container_project_id] = h.fetch_path(:project, :id)
    end

    save_inventory_multi(ems.container_limits, hashes, :use_association, [:ems_ref], :container_limit_items, :project)
    store_ids_for_new_records(ems.container_limits, hashes, :ems_ref)
  end

  def save_container_limit_items_inventory(container_limit, hashes)
    return if hashes.nil?
    container_limit.container_limit_items.reset

    save_inventory_multi(container_limit.container_limit_items, hashes, :use_association, [:resource, :item_type])
    store_ids_for_new_records(container_limit.container_limit_items, hashes, [:resource, :item_type])
  end

  def save_container_routes_inventory(ems, hashes)
    return if hashes.nil?

    ems.container_routes.reset

    hashes.each do |h|
      h[:container_project_id] = h.fetch_path(:project, :id)
      h[:container_service_id] = h.fetch_path(:container_service, :id)
    end

    save_inventory_multi(ems.container_routes, hashes, :use_association, [:ems_ref],
                         [:labels, :tags], [:container_service, :project, :namespace])
    store_ids_for_new_records(ems.container_routes, hashes, :ems_ref)
  end

  def save_container_nodes_inventory(ems, hashes)
    return if hashes.nil?

    ems.container_nodes.reset

    save_inventory_multi(ems.container_nodes, hashes, :use_association, [:ems_ref],
                         [:labels, :tags, :computer_system, :container_conditions,
                          :additional_attributes], [:namespace], true)

    store_ids_for_new_records(ems.container_nodes, hashes, :ems_ref)
  end

  def save_container_replicators_inventory(ems, hashes)
    return if hashes.nil?

    ems.container_replicators.reset

    hashes.each do |h|
      h[:container_project_id] = h.fetch_path(:project, :id)
    end

    save_inventory_multi(ems.container_replicators, hashes, :use_association, [:ems_ref],
                         [:labels, :tags, :selector_parts], [:project, :namespace])
    store_ids_for_new_records(ems.container_replicators, hashes, :ems_ref)
  end

  def save_container_services_inventory(ems, hashes)
    return if hashes.nil?

    ems.container_services.reset

    hashes.each do |h|
      h[:container_group_ids]         = h[:container_groups].map { |x| x[:id] }
      h[:container_project_id]        = h.fetch_path(:project, :id)
      h[:container_image_registry_id] = h.fetch_path(:container_image_registry, :id)
    end

    save_inventory_multi(ems.container_services, hashes, :use_association, [:ems_ref],
                         [:labels, :tags, :selector_parts, :container_service_port_configs],
                         [:container_groups, :project, :container_image_registry, :namespace])

    store_ids_for_new_records(ems.container_services, hashes, :ems_ref)
  end

  def save_container_groups_inventory(ems, hashes)
    return if hashes.nil?

    ems.container_groups.reset

    hashes.each do |h|
      h[:container_node_id]       = h.fetch_path(:container_node, :id)
      h[:container_replicator_id] = h.fetch_path(:container_replicator, :id)
      h[:container_project_id]    = h.fetch_path(:project, :id)
      h[:container_build_pod_id]  = ems.container_build_pods.find_by(:name      => h[:build_pod_name],
                                                                     :namespace => h.fetch_path(:project, :name)).try(:id)
    end

    save_inventory_multi(ems.container_groups, hashes, :use_association, [:ems_ref],
                         [:containers, :labels, :tags,
                          :node_selector_parts, :container_conditions, :container_volumes],
                         [:container_node, :container_replicator, :project, :namespace, :build_pod_name],
                         true)
    store_ids_for_new_records(ems.container_groups, hashes, :ems_ref)
  end

  def save_containers_inventory(container_group, hashes)
    return if hashes.nil?

    container_group.containers.reset

    hashes.each do |h|
      h[:ems_id] = container_group[:ems_id]
      h[:container_image_id] = h.fetch_path(:container_image, :id)
    end

    save_inventory_multi(container_group.containers, hashes, :use_association, [:ems_ref],
                         [:container_port_configs, :container_env_vars, :security_context],
                         [:container_image], true)
    store_ids_for_new_records(container_group.containers, hashes, :ems_ref)
  end

  def save_container_port_configs_inventory(container, hashes)
    return if hashes.nil?

    container.container_port_configs.reset

    save_inventory_multi(container.container_port_configs, hashes, :use_association, [:ems_ref])
    store_ids_for_new_records(container.container_port_configs, hashes, :ems_ref)
  end

  def save_container_service_port_configs_inventory(container_service, hashes)
    return if hashes.nil?

    container_service.container_service_port_configs.reset

    save_inventory_multi(container_service.container_service_port_configs, hashes, :use_association, [:name])
    store_ids_for_new_records(container_service.container_service_port_configs, hashes, :name)
  end

  def save_container_env_vars_inventory(container, hashes)
    return if hashes.nil?
    container.container_env_vars.reset

    save_inventory_multi(container.container_env_vars, hashes, :use_association, [:name, :value, :field_path])
    store_ids_for_new_records(container.container_env_vars, hashes, [:name, :value, :field_path])
  end

  def save_container_images_inventory(ems, hashes)
    return if hashes.nil?

    ems.container_images.reset

    hashes.each do |h|
      h[:container_image_registry_id] = h[:container_image_registry][:id] unless h[:container_image_registry].nil?
      h[:type] ||= 'ContainerImage'
    end

    save_inventory_multi(ems.container_images, hashes, :use_association, [:image_ref, :container_image_registry_id],
                         [:labels, :docker_labels], :container_image_registry, true)
    store_ids_for_new_records(ems.container_images, hashes,
                              [:image_ref, :container_image_registry_id])
  end

  def save_container_image_registries_inventory(ems, hashes)
    return if hashes.nil?

    ems.container_image_registries.reset

    save_inventory_multi(ems.container_image_registries, hashes, :use_association, [:host, :port])
    store_ids_for_new_records(ems.container_image_registries, hashes, [:host, :port])
  end

  def save_container_conditions_inventory(container_entity, hashes)
    return if hashes.nil?

    container_entity.container_conditions.reset

    save_inventory_multi(container_entity.container_conditions, hashes, :use_association, [:name])
    store_ids_for_new_records(container_entity.container_conditions, hashes, :name)
  end

  def save_security_context_inventory(container, hash)
    save_inventory_single(:security_context, container, hash)
  end

  def save_container_volumes_inventory(container_group, hashes)
    return if hashes.nil?

    container_group.container_volumes.reset

    hashes.each do |h|
      h[:persistent_volume_claim_id] = h.fetch_path(:persistent_volume_claim, :id)
    end

    save_inventory_multi(container_group.container_volumes, hashes, :use_association,
                         [:name], [], [:persistent_volume_claim])
    store_ids_for_new_records(container_group.container_volumes, hashes, :name)
  end

  def save_additional_attributes_inventory(entity, hashes)
    save_custom_attribute_attribute_inventory(entity, :additional_attributes, hashes)
  end

  def save_custom_attribute_attribute_inventory(entity, attribute_name, hashes)
    return if hashes.nil?

    entity.send(attribute_name).reset

    save_inventory_multi(entity.send(attribute_name),
                         hashes, :use_association, [:section, :name])
    store_ids_for_new_records(entity.send(attribute_name),
                              hashes, [:section, :name])
  end

  def save_labels_inventory(entity, hashes)
    save_custom_attribute_attribute_inventory(entity, :labels, hashes)
  end

  def save_docker_labels_inventory(entity, hashes)
    save_custom_attribute_attribute_inventory(entity, :docker_labels, hashes)
  end

  def save_selector_parts_inventory(entity, hashes)
    return if hashes.nil?

    entity.selector_parts.reset

    save_inventory_multi(entity.selector_parts, hashes, :use_association, [:section, :name])
    store_ids_for_new_records(entity.selector_parts, hashes, [:section, :name])
  end

  def save_node_selector_parts_inventory(entity, hashes)
    return if hashes.nil?

    entity.node_selector_parts.reset

    save_inventory_multi(entity.node_selector_parts, hashes, :use_association, [:section, :name])
    store_ids_for_new_records(entity.node_selector_parts, hashes, [:section, :name])
  end

  def save_container_builds_inventory(ems, hashes)
    return if hashes.nil?

    ems.container_builds.reset

    hashes.each do |h|
      h[:container_project_id] = h.fetch_path(:project, :id)
    end
    save_inventory_multi(ems.container_builds, hashes, :use_association, [:ems_ref], [:labels, :tags],
                         [:project, :resources])
    store_ids_for_new_records(ems.container_builds, hashes, :ems_ref)
  end

  def save_container_build_pods_inventory(ems, hashes)
    return if hashes.nil?

    ems.container_build_pods.reset

    hashes.each do |h|
      h[:container_build_id] = h.fetch_path(:build_config, :id)
    end

    save_inventory_multi(ems.container_build_pods, hashes, :use_association, [:ems_ref], [:labels,],
                         [:build_config])
    store_ids_for_new_records(ems.container_build_pods, hashes, :ems_ref)
  end

  def save_container_templates_inventory(ems, hashes)
    return if hashes.nil?

    ems.container_templates.reset

    hashes.each do |h|
      h[:container_project_id] = h.fetch_path(:container_project, :id)
    end

    save_inventory_multi(ems.container_templates, hashes, :use_association, [:ems_ref],
                         [:container_template_parameters, :labels], [:container_project, :namespace])
    store_ids_for_new_records(ems.container_templates, hashes, :ems_ref)
  end

  def save_container_template_parameters_inventory(container_template, hashes)
    return if hashes.nil?

    container_template.container_template_parameters.reset

    save_inventory_multi(container_template.container_template_parameters, hashes, :use_association, [:name], [], [])
    store_ids_for_new_records(container_template.container_template_parameters, hashes, :name)
  end
end
