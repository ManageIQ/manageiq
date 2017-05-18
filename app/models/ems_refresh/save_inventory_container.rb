module EmsRefresh::SaveInventoryContainer
  def save_ems_container_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    graph_keys = [:container_projects, :container_quotas, :container_nodes,
                  :container_image_registries, :container_images,
                 ]
    child_keys = [:container_replicators, :container_groups,
                  :container_services, :container_routes, :container_component_statuses, :container_templates,
                  # things moved to end - if they work here, nothing depended on their ids
                  :container_limits, :container_builds, :container_build_pods,
                  :persistent_volume_claims, :persistent_volumes,
                 ]

    # TODO: deleting vs archiving!

    initialize_inventory_collections(ems)
    graph_keys.each do |k|
      send("graph_#{k}_inventory", ems, hashes[k])
    end
    ManagerRefresh::SaveInventory.save_inventory(ems, @inv_collections.values)

    tmp_store_ids_for_graph_saved(ems, hashes.slice(*graph_keys)) # TODELETE

    # Save and link other subsections
    child_keys.each do |k|
      send("save_#{k}_inventory", ems, hashes[k], target)
    end

    ems.save!
  end

  def tmp_store_ids_for_graph_saved(ems, inventory)
    inventory.each do |name, hashes|
      association = ems.send(name)
      association.reset

      # hacks that were previously scattered, letting store_ids_for_new_records
      # follow associations in hashes, assuming those's [:id]s have already been set.
      store_keys = @inv_collections[name].manager_ref.map do |k|
       {:container_image_registry => :container_image_registry_id}.fetch(k, k)
      end
      hashes.each do |h|
        h[:container_image_registry_id] = h[:container_image_registry][:id] if h[:container_image_registry]
      end
      store_ids_for_new_records(association, hashes, store_keys)
    end

  end

  def initialize_inventory_collections(ems)
    # TODO: Targeted refreshes will require adjusting the associations / arels. (duh)
    @inv_collections = {}
    @inv_collections[:container_projects] = ::ManagerRefresh::InventoryCollection.new(
      :model_class => ContainerProject,
      :parent => ems,
      :builder_params => {:ems_id => ems.id},
      :association => :container_projects
    )
    @inv_collections[:container_quotas] = ::ManagerRefresh::InventoryCollection.new(
      :model_class => ContainerQuota,
      :parent => ems,
      :builder_params => {:ems_id => ems.id},
      :association => :container_quotas,
      #:arel => ContainerQuota.joins(:container_project).where(:container_projects => {:ems_id => ems.id}),
    )
    @inv_collections[:container_quota_items] = ::ManagerRefresh::InventoryCollection.new(
      :model_class => ContainerQuotaItem,
      :parent => ems,
      :association => :container_quota_items,
      #:arel => ContainerQuotaItem.joins(:container_quota => :container_project).where(:container_projects => {:ems_id => ems.id}),
      :manager_ref => [:container_quota, :resource],
    )
    @inv_collections[:container_nodes] = ::ManagerRefresh::InventoryCollection.new(
      :model_class => ContainerNode,
      :parent => ems,
      :builder_params => {:ems_id => ems.id},
      :association => :container_nodes,
    )
    # ContainerCondition is polymorphic child of ContainerNode & ContainerGroup
    @inv_collections[:container_node_conditions] = ::ManagerRefresh::InventoryCollection.new(
      :model_class => ContainerCondition,
      :parent => ems,
      :association => :container_node_conditions,
      #:arel => ContainerCondition.joins(
      #  'INNER JOIN "container_nodes" ON "container_conditions"."container_entity_id" = "container_nodes"."id"'
      #).where(:container_entity_type => 'ContainerNode',
      #        :container_nodes => {:ems_id => ems.id}),
      :manager_ref => [:container_entity, :name],
    )

    # polymorphic child of ContainerNode & ContainerImage
    # TODO these are dumb, find way to share same InventoryCollections via both.
    @inv_collections[:container_node_computer_systems] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ComputerSystem,
        :parent => ems,
        :association => :container_node_computer_systems,
        :manager_ref => [:managed_entity],
      )
    @inv_collections[:container_node_computer_system_hardwares] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => Hardware,
        :parent => ems,
        # can't nest has_many through
        :arel => Hardware.joins(:computer_system => :container_node)
                         .where(:container_nodes => {:ems_id => ems.id}),
        :manager_ref => [:computer_system],
      )
    @inv_collections[:container_node_computer_system_operating_systems] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => OperatingSystem,
        :parent => ems,
        # can't nest has_many through
        :arel => OperatingSystem.joins(:computer_system => :container_node)
                                .where(:container_nodes => {:ems_id => ems.id}),
        :manager_ref => [:computer_system],
      )

    @inv_collections[:container_image_registries] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerImageRegistry,
        :parent => ems,
        :builder_params => {:ems_id => ems.id},
        :association => :container_image_registries,
        :manager_ref => [:host, :port],
      )
    @inv_collections[:container_images] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerImage,
        :parent => ems,
        :builder_params => {:ems_id => ems.id},
        :association => :container_images,
        :manager_ref => [:image_ref, :container_image_registry],
      )
  end

  def graph_container_projects_inventory(ems, hashes)
    hashes.to_a.each do |h|
      @inv_collections[:container_projects].build(h)
    end

    # TODO children [:labels, :tags], [], true)
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

  def graph_container_quotas_inventory(ems, hashes)
    hashes.to_a.each do |h|
      h = h.merge(
        :container_project =>  @inv_collections[:container_projects].lazy_find(h.delete(:project)[:ems_ref])
      )
      items = h.delete(:container_quota_items)
      graph_container_quota_items_inventory(h, items)
      @inv_collections[:container_quotas].build(h)
    end
  end

  def graph_container_quota_items_inventory(container_quota, hashes)
    hashes.to_a.each do |h|
      h = h.merge(
        :container_quota => @inv_collections[:container_quotas].lazy_find(container_quota[:ems_ref]),
      )
      @inv_collections[:container_quota_items].build(h)
    end
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

  def graph_container_nodes_inventory(ems, hashes)
    hashes.to_a.each do |h|
      h = h.except(:labels, :tags, :additional_attributes) # TODO children
      h = h.except(:namespace)
      node = @inv_collections[:container_nodes].lazy_find(h[:ems_ref])
      graph_container_node_conditions_inventory(node, h.delete(:container_conditions))
      graph_computer_system_inventory(node, h.delete(:computer_system))
      @inv_collections[:container_nodes].build(h)
    end
  end

  def graph_computer_system_inventory(parent, hash)
    return if hash.nil?
    hash = hash.merge(:managed_entity => parent)
    # TODO: there is probably is shorter way to link them?
    # I've done this in other places by giving the children a lazy_find for the parent.
    # But that's also silly, if I'm building the parent here too.
    hw = hash.delete(:hardware)
    os = hash.delete(:operating_system)
    cs = @inv_collections[:container_node_computer_systems].build(hash)
    @inv_collections[:container_node_computer_system_hardwares].build(hw.merge(:computer_system => cs))
    @inv_collections[:container_node_computer_system_operating_systems].build(os.merge(:computer_system => cs))
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

  def graph_container_images_inventory(ems, hashes)
    hashes.to_a.each do |h|
      h = h.merge(:container_image_registry => lazy_find_image_registry(h[:container_image_registry]))
      h = h.except(:labels, :docker_labels) # TODO
      @inv_collections[:container_images].build(h)
    end
  end

  def lazy_find_image_registry(hash)
    return nil if hash.nil?
    @inv_collections[:container_image_registries].lazy_find(
      @inv_collections[:container_image_registries].object_index(hash)
    )
  end

  def graph_container_image_registries_inventory(ems, hashes)
    hashes.to_a.each do |h|
      @inv_collections[:container_image_registries].build(h)
    end
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

  def graph_container_node_conditions_inventory(parent, hashes)
    hashes.to_a.each do |h|
      h = h.merge(:container_entity => parent)
      @inv_collections[:container_node_conditions].build(h)
    end
  end

  # still used for pods
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

  def save_additional_attributes_inventory(entity, hashes, target = nil)
    save_custom_attribute_attribute_inventory(entity, :additional_attributes, hashes, target)
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
