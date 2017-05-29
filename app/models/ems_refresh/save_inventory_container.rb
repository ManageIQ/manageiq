module EmsRefresh::SaveInventoryContainer
  def save_ems_container_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    graph_keys = [:container_projects, :container_quotas, :container_limits,
                  :container_nodes,
                  :container_image_registries, :container_images,
                  :container_groups, :container_replicators,
                  :container_services, :container_routes,
                  :container_component_statuses, :container_templates,
                  :container_builds, :container_build_pods,
                  :persistent_volume_claims, :persistent_volumes,
                 ]

    # TODO: deleting vs archiving!

    initialize_inventory_collections(ems)
    graph_keys.each do |k|
      send("graph_#{k}_inventory", ems, hashes[k])
    end
    ManagerRefresh::SaveInventory.save_inventory(ems, @inv_collections.values)
  end

  def tmp_store_ids_for_graph_saved(ems, inventory)
    inventory.each do |name, hashes|
      association = ems.send(name)
      association.reset

      # hacks that were previously scattered, letting store_ids_for_new_records
      # follow associations in hashes, assuming those's [:id]s have already been set.
      find_keys = @inv_collections[name].manager_ref.map do |k|
       {:container_image_registry => :container_image_registry_id}.fetch(k, k)
      end
      hashes.each do |h|
        h[:container_image_registry_id] = h[:container_image_registry][:id] if h[:container_image_registry]
      end
      store_ids_for_new_records(association, hashes, find_keys)
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
    @inv_collections[:container_limits] = ::ManagerRefresh::InventoryCollection.new(
      :model_class => ContainerLimit,
      :parent => ems,
      :builder_params => {:ems_id => ems.id},
      :association => :container_limits,
    )
    @inv_collections[:container_limit_items] = ::ManagerRefresh::InventoryCollection.new(
      :model_class => ContainerLimitItem,
      :parent => ems,
      :association => :container_limit_items,
      :manager_ref => [:container_limit, :resource, :item_type],
    )
    @inv_collections[:container_nodes] = ::ManagerRefresh::InventoryCollection.new(
      :model_class => ContainerNode,
      :parent => ems,
      :builder_params => {:ems_id => ems.id},
      :association => :container_nodes,
    )

    # polymorphic child of ContainerNode & ContainerImage,
    # but refresh only sets it on nodes.
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
        # can't nest has_many through ?
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

    @inv_collections[:container_groups] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerGroup,
        :parent => ems,
        :builder_params => {:ems_id => ems.id},
        :association => :container_groups,
      )
    @inv_collections[:container_definitions] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerDefinition,
        :parent => ems,
        :builder_params => {:ems_id => ems.id},
        :association => :container_definitions,
        # parser sets :ems_ref => "#{pod_id}_#{container_def.name}_#{container_def.image}"
      )
    @inv_collections[:container_volumes] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerVolume,
        :parent => ems,
        :association => :container_volumes,
        :manager_ref => [:parent, :name],
      )
    @inv_collections[:containers] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => Container,
        :parent => ems,
        :builder_params => {:ems_id => ems.id},
        :association => :containers,
        # parser sets :ems_ref => "#{pod_id}_#{container.name}_#{container.image}"
      )
    @inv_collections[:container_port_configs] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerPortConfig,
        :parent => ems,
        :association => :container_port_configs,
        # parser sets :ems_ref => "#{pod_id}_#{container_name}_#{port_config.containerPort}_#{port_config.hostPort}_#{port_config.protocol}"
      )
    @inv_collections[:container_env_vars] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerEnvVar,
        :parent => ems,
        :association => :container_env_vars,
        # TODO: old save matches on all :name, :value, :field_path - does this matter?
        :manager_ref => [:container_definition, :name],
      )
    @inv_collections[:security_contexts] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => SecurityContext,
        :parent => ems,
        :association => :security_contexts,
        :manager_ref => [:resource],
      )

    @inv_collections[:container_replicators] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerReplicator,
        :parent => ems,
        :builder_params => {:ems_id => ems.id},
        :association => :container_replicators,
      )
    @inv_collections[:container_services] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerService,
        :parent => ems,
        :builder_params => {:ems_id => ems.id},
        :association => :container_services,
      )
    @inv_collections[:container_service_port_configs] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerServicePortConfig,
        :parent => ems,
        :association => :container_service_port_configs,
      )
    @inv_collections[:container_routes] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerRoute,
        :parent => ems,
        :builder_params => {:ems_id => ems.id},
        :association => :container_routes,
      )
    @inv_collections[:container_component_statuses] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerComponentStatus,
        :parent => ems,
        :builder_params => {:ems_id => ems.id},
        :association => :container_component_statuses,
        :manager_ref => [:name],
      )
    @inv_collections[:container_templates] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerTemplate,
        :parent => ems,
        :builder_params => {:ems_id => ems.id},
        :association => :container_templates,
      )
    @inv_collections[:container_template_parameters] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerTemplateParameter,
        :parent => ems,
        :association => :container_template_parameters,
        :manager_ref => [:container_template, :name],
      )
    @inv_collections[:container_builds] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerBuild,
        :parent => ems,
        :builder_params => {:ems_id => ems.id},
        :association => :container_builds,
      )
    @inv_collections[:container_build_pods] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => ContainerBuildPod,
        :parent => ems,
        :builder_params => {:ems_id => ems.id},
        :association => :container_build_pods,
        # TODO is this unique?  build pods do have uid that becomes ems_ref,
        # but we need lazy_find by name for lookup from container_group
        # TODO replace namespace with container_project_id column?
        :manager_ref => [:namespace, :name],
      )
    @inv_collections[:persistent_volumes] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => PersistentVolume,
        :parent => ems,
        :builder_params => {:parent => ems},
        :association => :persistent_volumes,
      )
    @inv_collections[:persistent_volume_claims] =
      ::ManagerRefresh::InventoryCollection.new(
        :model_class => PersistentVolumeClaim,
        :parent => ems,
        :builder_params => {:ems_id => ems.id},
        :association => :persistent_volume_claims,
      )
  end

  # ContainerCondition is polymorphic child of ContainerNode & ContainerGroup
  def container_conditions_query_for(relation)
    #:arel => ContainerCondition.joins(
    #  'INNER JOIN "container_nodes" ON "container_conditions"."container_entity_id" = "container_nodes"."id"'
    #).where(:container_entity_type => 'ContainerNode', :container_nodes => {:ems_id => ems.id}),

    # Nested SELECT, dunno if better than JOIN but upside is "structurally compatible" for .or()
    ContainerCondition.where(:container_entity_type => relation.model.name, :container_entity_id => relation)
  end

  def container_conditions_for(relation)
    # TODO: what if last parent disappears, will this ||= never happen
    #   and the ContainerConditions won't be deleted?
    @inv_collections[[:container_conditions_for, relation.model.name]] ||= ::ManagerRefresh::InventoryCollection.new(
      :model_class => ContainerCondition,
      :arel => container_conditions_query_for(relation),
      :manager_ref => [:container_entity, :name],
    )
  end

  def custom_attributes_query_for(relation, section)
    CustomAttribute.where(:resource_type => relation.model.name,
                          :resource_id => relation,
                          :section => section)
  end

  def custom_attributes_for(relation, section)
    @inv_collections[[:custom_attributes_for, relation.model.name, section]] ||= ::ManagerRefresh::InventoryCollection.new(
      :model_class => CustomAttribute,
      :arel => custom_attributes_query_for(relation, section),
      :manager_ref => [:resource, :section, :name],
    )
  end

  def lazy_find_project(hash)
    @inv_collections[:container_projects].lazy_find(hash[:ems_ref])
  end

  def graph_container_projects_inventory(ems, hashes)
    hashes.to_a.each do |h|
      @inv_collections[:container_projects].build(h)
    end

    # TODO children [:labels, :tags], [], true)
  end

  def graph_persistent_volumes_inventory(ems, hashes)
    hashes.to_a.each do |h|
      h = h.dup
      h.except!(:namespace)
      h[:persistent_volume_claim] = lazy_find_pvc(h[:persistent_volume_claim])
      @inv_collections[:persistent_volumes].build(h)
    end
  end

  def lazy_find_pvc(hash)
    return nil if hash.nil?  # TODO in every lazy_find_*?
    @inv_collections[:persistent_volume_claims].lazy_find(hash[:ems_ref])
  end

  def graph_persistent_volume_claims_inventory(ems, hashes)
    hashes.to_a.each do |h|
      h = h.dup
      h.except!(:namespace)
      @inv_collections[:persistent_volume_claims].build(h)
    end
  end

  def graph_container_quotas_inventory(ems, hashes)
    hashes.to_a.each do |h|
      h = h.merge(
        # TODO: rename :project to :container_project in parser?
        :container_project =>  lazy_find_project(h.delete(:project))
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

  def graph_container_limits_inventory(ems, hashes)
    hashes.to_a.each do |h|
      h = h.dup
      h[:container_project] = lazy_find_project(h.delete(:project))
      h.delete(:namespace)
      children = h.extract!(:container_limit_items)

      limit = @inv_collections[:container_limits].build(h)
      graph_container_limit_items_inventory(limit, children[:container_limit_items])
    end
  end

  def graph_container_limit_items_inventory(container_limit, hashes)
    hashes.to_a.each do |h|
      h = h.merge(:container_limit => container_limit)
      @inv_collections[:container_limit_items].build(h)
    end
  end

  def graph_container_routes_inventory(ems, hashes)
    hashes.to_a.each do |h|
      h = h.dup
      h[:container_project] = lazy_find_project(h.delete(:project))
      h.delete(:namespace)
      h[:container_service] = lazy_find_container_service(h[:container_service])
      custom_attrs = h.extract!(:labels)
      h.delete(:tags) # TODO

      route = @inv_collections[:container_routes].build(h)
      graph_custom_attributes_multi(ems.container_routes, route, custom_attrs)
    end
  end

  def lazy_find_node(hash)
    @inv_collections[:container_nodes].lazy_find(hash[:ems_ref])
  end

  def graph_container_nodes_inventory(ems, hashes)
    hashes.to_a.each do |h|
      h = h.except(:namespace)
      custom_attrs = h.extract!(:labels, :additional_attributes)
      children = h.extract!(:container_conditions, :computer_system)
      h.except!(:tags) # TODO

      node = @inv_collections[:container_nodes].build(h)
      graph_container_conditions_inventory(ems.container_nodes, node, children[:container_conditions])
      graph_computer_system_inventory(node, children[:computer_system])
      graph_custom_attributes_multi(ems.container_nodes, node, custom_attrs)
    end
  end

  def graph_computer_system_inventory(parent, hash)
    return if hash.nil?
    hash = hash.merge(:managed_entity => parent)
    children = hash.extract!(:hardware, :operating_system)
    cs = @inv_collections[:container_node_computer_systems].build(hash)
    @inv_collections[:container_node_computer_system_hardwares].build(
      children[:hardware].merge(:computer_system => cs)
    )
    @inv_collections[:container_node_computer_system_operating_systems].build(
      children[:operating_system].merge(:computer_system => cs)
    )
  end

  def lazy_find_replicator(hash)
    @inv_collections[:container_replicators].lazy_find(hash[:ems_ref])
  end

  def graph_container_replicators_inventory(ems, hashes)
    hashes.each do |h|
      h = h.merge(:container_project => lazy_find_project(h.delete(:project)))
      h.delete(:namespace)
      custom_attrs = h.extract!(:labels, :selector_parts)
      h = h.except(:tags) # TODO

      replicator = @inv_collections[:container_replicators].build(h)
      graph_custom_attributes_inventory(ems.container_replicators, replicator,
                                        :labels, custom_attrs[:labels])
      # TODO: rename in parser?  can't because the scope is called replicator.selector_parts.
      # could do something like .send(association_name), prefer explicit section.
      graph_custom_attributes_inventory(ems.container_replicators, replicator,
                                        :selectors, custom_attrs[:selector_parts])
    end
  end

  def lazy_find_container_service(hash)
    @inv_collections[:container_services].lazy_find(hash[:ems_ref])
  end

  def graph_container_services_inventory(ems, hashes)
    hashes.to_a.each do |h|
      h = h.dup
      h[:container_project] = lazy_find_project(h.delete(:project))
      h.delete(:namespace)
      h[:container_image_registry] = lazy_find_image_registry(h[:container_image_registry])
      h[:container_groups] = h[:container_groups].collect { |g| lazy_find_container_group(g) }
      custom_attrs = h.extract!(:labels, :selector_parts)
      h.except!(:tags) # TODO
      children = h.extract!(:container_service_port_configs)

      service = @inv_collections[:container_services].build(h)
      graph_custom_attributes_multi(ems.container_services, service, custom_attrs)
      graph_container_service_port_configs_inventory(service, children[:container_service_port_configs])
    end
  end

  def lazy_find_container_group(hash)
    @inv_collections[:container_groups].lazy_find(hash[:ems_ref])
  end

  def graph_container_groups_inventory(ems, hashes)
    hashes.to_a.each do |h|
      h = h.dup
      h[:container_node] = lazy_find_node(h[:container_node])
      project = h.delete(:project)
      h[:container_project] = lazy_find_project(project)
      h.delete(:namespace)
      h[:container_build_pod] = lazy_find_build_pod(
        :namespace => project[:name],
        :name      => h.delete(:build_pod_name)
      )
      # might not have a replicator.
      # TODO review all lazy_find links, probably most are optional!
      h[:container_replicator] &&= lazy_find_replicator(h[:container_replicator])

      custom_attrs = h.extract!(:labels, :node_selector_parts)
      h.except!(:tags) # TODO
      children = h.extract!(
        :container_definitions, :containers, :container_conditions, :container_volumes,
      )

      cg = @inv_collections[:container_groups].build(h)
      graph_container_definitions_inventory(cg, children[:container_definitions])
      graph_container_conditions_inventory(ems.container_groups, cg, children[:container_conditions])
      graph_container_volumes_inventory(cg, children[:container_volumes])
      graph_custom_attributes_multi(ems.container_groups, cg, custom_attrs)
    end
  end

  def graph_container_definitions_inventory(container_group, hashes)
    hashes.to_a.each do |h|
      h = h.merge(:container_group => container_group)
      children = h.extract!(
        :container_port_configs, :container_env_vars, :security_context, :container
      )
      cd = @inv_collections[:container_definitions].build(h)
      graph_container_port_configs_inventory(cd, children[:container_port_configs])
      graph_container_env_vars_inventory(cd, children[:container_env_vars])
      graph_security_context_inventory(cd, children[:security_context])
      graph_container_inventory(cd, children[:container])
    end
  end

  def graph_container_port_configs_inventory(container_definition, hashes)
    hashes.to_a.each do |h|
      h = h.merge(:container_definition => container_definition)
      @inv_collections[:container_port_configs].build(h)
    end
  end

  def graph_container_service_port_configs_inventory(container_service, hashes)
    hashes.to_a.each do |h|
      h = h.merge(:container_service => container_service)
      @inv_collections[:container_service_port_configs].build(h)
    end
  end

  def graph_container_env_vars_inventory(container_definition, hashes)
    hashes.to_a.each do |h|
      h = h.merge(:container_definition => container_definition)
      @inv_collections[:container_env_vars].build(h)
    end
  end

  def lazy_find_image(hash)
    return nil if hash.nil?
    hash = hash.merge(:container_image_registry => lazy_find_image_registry(hash[:container_image_registry]))
    @inv_collections[:container_images].lazy_find(
      @inv_collections[:container_images].object_index(hash)
    )
  end

  def graph_container_images_inventory(ems, hashes)
    hashes.to_a.each do |h|
      h = h.merge(:container_image_registry => lazy_find_image_registry(h[:container_image_registry]))
      custom_attrs = h.extract!(:labels, :docker_labels)

      image = @inv_collections[:container_images].build(h)
      graph_custom_attributes_multi(ems.container_images, image, custom_attrs)
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

  def graph_container_component_statuses_inventory(ems, hashes)
    hashes.to_a.each do |h|
      @inv_collections[:container_component_statuses].build(h)
    end
  end

  def graph_container_inventory(container_definition, hash)
    # TODO: understand below comment & test :-)
    # The hash could be nil when the container is in transition (still downloading
    # the image, or stuck in Pending, or unable to fetch the image),
    # in which case should delete any pre-existing entity in containers.
    if hash
      hash = hash.merge(:container_definition => container_definition)
      hash[:container_image] = lazy_find_image(hash[:container_image])
      @inv_collections[:containers].build(hash)
    end
  end

  def graph_container_conditions_inventory(relation, parent, hashes)
    hashes.to_a.each do |h|
      h = h.merge(:container_entity => parent)
      container_conditions_for(relation).build(h)
    end
  end

  def graph_security_context_inventory(resource, hash)
    return if hash.nil?
    hash = hash.merge(:resource => resource)
    @inv_collections[:security_contexts].build(hash)
  end

  def graph_container_volumes_inventory(parent, hashes)
    hashes.to_a.each do |h|
      h = h.dup
      h[:parent] = parent
      h[:persistent_volume_claim] = lazy_find_pvc(h[:persistent_volume_claim])
      @inv_collections[:container_volumes].build(h)
    end
  end

  # TODO: use keyword args, don't repeat save_inventory_multi
  def graph_custom_attributes_multi(relation, parent, hashes_by_section)
    hashes_by_section.each do |section, hashes|
      graph_custom_attributes_inventory(relation, parent, section, hashes)
    end
  end

  def graph_custom_attributes_inventory(relation, parent, section, hashes)
    hashes.to_a.each do |h|
      h = h.merge(:resource => parent)
      custom_attributes_for(relation, section).build(h)
    end
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

  # TODO
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

  def lazy_find_build(hash)
    @inv_collections[:container_builds].lazy_find(hash[:ems_ref])
  end

  def graph_container_builds_inventory(ems, hashes)
    hashes.to_a.each do |h|
      h = h.dup
      h[:container_project] = lazy_find_project(h.delete(:project))
      h.except!(:namespace, :resources)
      h.except!(:tags) # TODO
      custom_attrs = h.extract!(:labels)

      build = @inv_collections[:container_builds].build(h)
      graph_custom_attributes_multi(ems.container_builds, build, custom_attrs)
    end
  end

  def lazy_find_build_pod(hash)
    @inv_collections[:container_build_pods].lazy_find(
      @inv_collections[:container_build_pods].object_index(hash)
    )
  end

  def graph_container_build_pods_inventory(ems, hashes)
    hashes.to_a.each do |h|
      h = h.dup
      h[:container_build] = lazy_find_build(h.delete(:build_config))
      custom_attrs = h.extract!(:labels)

      build_pod = @inv_collections[:container_build_pods].build(h)
      graph_custom_attributes_multi(ems.container_build_pods, build_pod, custom_attrs)
    end
  end

  def graph_container_templates_inventory(ems, hashes)
    hashes.to_a.each do |h|
      h = h.dup
      h[:container_project] = lazy_find_project(h.delete(:container_project))
      h.delete(:namespace)
      custom_attrs = h.extract!(:labels)
      children = h.extract!(:container_template_parameters) # TODO save

      template = @inv_collections[:container_templates].build(h)
      graph_custom_attributes_multi(ems.container_templates, template, custom_attrs)
      graph_container_template_parameters_inventory(template, children[:container_template_parameters])
    end
  end

  def graph_container_template_parameters_inventory(container_template, hashes)
    hashes.to_a.each do |h|
      h = h.merge(:container_template => container_template)
      @inv_collections[:container_template_parameters].build(h)
    end
  end
end
