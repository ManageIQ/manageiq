class TestContainersPersister < ManagerRefresh::Inventory::Persister
  def shared_options
    settings_options = options[:inventory_collections].try(:to_hash) || {}

    settings_options.merge(
      :targeted => false,
      :strategy => :local_db_find_missing_references, # By default no IC will be saved
      :complete => false # we have to do :targeted => true instead
    )
  end

  def initialize_inventory_collections
    # TODO: Targeted refreshes will require adjusting the associations / arels. (duh)
    @collections[:container_projects] = ::ManagerRefresh::InventoryCollection.new(
      shared_options.merge(
        :model_class    => ContainerProject,
        :parent         => manager,
        :builder_params => {:ems_id => manager.id},
        :association    => :container_projects,
        :secondary_refs => {:by_name => [:name]},
        :delete_method  => :disconnect_inv,
      )
    )
    initialize_custom_attributes_collections(@collections[:container_projects], %w(labels additional_attributes))
    initialize_taggings_collection(@collections[:container_projects])

    @collections[:container_quotas] = ::ManagerRefresh::InventoryCollection.new(
      shared_options.merge(
        :model_class          => ContainerQuota,
        :parent               => manager,
        :builder_params       => {:ems_id => manager.id},
        :association          => :container_quotas,
        :attributes_blacklist => [:namespace],
      )
    )
    @collections[:container_quota_scopes] = ::ManagerRefresh::InventoryCollection.new(
      shared_options.merge(
        :model_class => ContainerQuotaScope,
        :parent      => manager,
        :association => :container_quota_scopes,
        :manager_ref => [:container_quota, :scope],
      )
    )
    @collections[:container_quota_items] = ::ManagerRefresh::InventoryCollection.new(
      shared_options.merge(
        :model_class => ContainerQuotaItem,
        :parent      => manager,
        :association => :container_quota_items,
        :manager_ref => [:container_quota, :resource],
      )
    )
    @collections[:container_limits] = ::ManagerRefresh::InventoryCollection.new(
      shared_options.merge(
        :model_class          => ContainerLimit,
        :parent               => manager,
        :builder_params       => {:ems_id => manager.id},
        :association          => :container_limits,
        :attributes_blacklist => [:namespace],
      )
    )
    @collections[:container_limit_items] = ::ManagerRefresh::InventoryCollection.new(
      shared_options.merge(
        :model_class => ContainerLimitItem,
        :parent      => manager,
        :association => :container_limit_items,
        :manager_ref => [:container_limit, :resource, :item_type],
      )
    )
    @collections[:container_nodes] = ::ManagerRefresh::InventoryCollection.new(
      shared_options.merge(
        :model_class    => ContainerNode,
        :parent         => manager,
        :builder_params => {:ems_id => manager.id},
        :association    => :container_nodes,
        :secondary_refs => {:by_name => [:name]},
      )
    )
    initialize_container_conditions_collection(manager, :container_nodes)
    initialize_custom_attributes_collections(@collections[:container_nodes], %w(labels additional_attributes))
    initialize_taggings_collection(@collections[:container_nodes])

    # polymorphic child of ContainerNode & ContainerImage,
    # but refresh only sets it on nodes.
    @collections[:computer_systems]                  =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class => ComputerSystem,
          :parent      => manager,
          :association => :computer_systems,
          :manager_ref => [:managed_entity],
        )
      )
    @collections[:computer_system_hardwares]         =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class => Hardware,
          :parent      => manager,
          :association => :computer_system_hardwares,
          :manager_ref => [:computer_system],
        )
      )
    @collections[:computer_system_operating_systems] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class => OperatingSystem,
          :parent      => manager,
          :association => :computer_system_operating_systems,
          :manager_ref => [:computer_system],
        )
      )

    @collections[:container_image_registries] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class    => ContainerImageRegistry,
          :parent         => manager,
          :builder_params => {:ems_id => manager.id},
          :association    => :container_image_registries,
          :manager_ref    => [:host, :port],
        )
      )
    @collections[:container_images] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class            => ContainerImage,
          :parent                 => manager,
          :builder_params         => {:ems_id => manager.id},
          :association            => :container_images,
          # TODO: old save matches on [:image_ref, :container_image_registry_id]
          # TODO: should match on digest when available
          :manager_ref            => [:image_ref],
          :delete_method          => :disconnect_inv,
          :custom_reconnect_block => custom_reconnect_block
        )
      )
    # images have custom_attributes but that's done conditionally in openshift parser

    @collections[:container_groups] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class            => ContainerGroup,
          :parent                 => manager,
          :builder_params         => {:ems_id => manager.id},
          :association            => :container_groups,
          :secondary_refs         => {:by_container_project_and_name => [:container_project, :name]},
          :attributes_blacklist   => [:namespace],
          :delete_method          => :disconnect_inv,
          :custom_reconnect_block => custom_reconnect_block
        )
      )
    initialize_container_conditions_collection(manager, :container_groups)
    initialize_custom_attributes_collections(@collections[:container_groups], %w(labels node_selectors))
    initialize_taggings_collection(@collections[:container_groups])

    @collections[:container_volumes]      =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class => ContainerVolume,
          :parent      => manager,
          :association => :container_volumes,
          :manager_ref => [:parent, :name],
        )
      )
    @collections[:containers]             =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class            => Container,
          :parent                 => manager,
          :builder_params         => {:ems_id => manager.id},
          :association            => :containers,
          # parser sets :ems_ref => "#{pod_id}_#{container.name}_#{container.image}"
          :delete_method          => :disconnect_inv,
          :custom_reconnect_block => custom_reconnect_block
        )
      )
    @collections[:container_port_configs] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class => ContainerPortConfig,
          :parent      => manager,
          :association => :container_port_configs,
        # parser sets :ems_ref => "#{pod_id}_#{container_name}_#{port_config.containerPort}_#{port_config.hostPort}_#{port_config.protocol}"
        )
      )
    @collections[:container_env_vars]     =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class => ContainerEnvVar,
          :parent      => manager,
          :association => :container_env_vars,
          :manager_ref => [:container, :name, :value, :field_path],
        )
      )
    @collections[:security_contexts]      =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class => SecurityContext,
          :parent      => manager,
          :association => :security_contexts,
          :manager_ref => [:resource],
        )
      )

    @collections[:container_replicators] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class          => ContainerReplicator,
          :parent               => manager,
          :builder_params       => {:ems_id => manager.id},
          :association          => :container_replicators,
          :secondary_refs       => {:by_container_project_and_name => [:container_project, :name]},
          :attributes_blacklist => [:namespace],
        )
      )
    initialize_custom_attributes_collections(@collections[:container_replicators], %w(labels selectors))
    initialize_taggings_collection(@collections[:container_replicators])

    @collections[:container_services] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class          => ContainerService,
          :parent               => manager,
          :builder_params       => {:ems_id => manager.id},
          :association          => :container_services,
          :secondary_refs       => {:by_container_project_and_name => [:container_project, :name]},
          :attributes_blacklist => [:namespace],
          :saver_strategy       => :default # TODO(perf) Can't use batch strategy because of usage of M:N container_groups relation
        )
      )
    initialize_custom_attributes_collections(@collections[:container_services], %w(labels selectors))
    initialize_taggings_collection(@collections[:container_services])

    @collections[:container_service_port_configs] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class => ContainerServicePortConfig,
          :parent      => manager,
          :association => :container_service_port_configs,
          :manager_ref => [:container_service, :name]
        )
      )

    @collections[:container_routes] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class          => ContainerRoute,
          :parent               => manager,
          :builder_params       => {:ems_id => manager.id},
          :association          => :container_routes,
          :attributes_blacklist => [:namespace],
        )
      )
    initialize_custom_attributes_collections(@collections[:container_routes], %w(labels))
    initialize_taggings_collection(@collections[:container_routes])

    @collections[:container_templates] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class          => ContainerTemplate,
          :parent               => manager,
          :builder_params       => {:ems_id => manager.id},
          :association          => :container_templates,
          :attributes_blacklist => [:namespace],
        )
      )
    initialize_custom_attributes_collections(@collections[:container_templates], %w(labels))
    initialize_taggings_collection(@collections[:container_templates])

    @collections[:container_template_parameters] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class => ContainerTemplateParameter,
          :parent      => manager,
          :association => :container_template_parameters,
          :manager_ref => [:container_template, :name],
        )
      )

    @collections[:container_builds] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class          => ContainerBuild,
          :parent               => manager,
          :builder_params       => {:ems_id => manager.id},
          :association          => :container_builds,
          :secondary_refs       => {:by_namespace_and_name => [:namespace, :name]},
        )
      )
    initialize_custom_attributes_collections(@collections[:container_builds], %w(labels))
    initialize_taggings_collection(@collections[:container_builds])

    @collections[:container_build_pods] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class    => ContainerBuildPod,
          :parent         => manager,
          :builder_params => {:ems_id => manager.id},
          :association    => :container_build_pods,
          # TODO: convert namespace column -> container_project_id?
          :manager_ref    => [:namespace, :name],
          :secondary_refs => {:by_namespace_and_name => [:namespace, :name]},
        )
      )
    initialize_custom_attributes_collections(@collections[:container_build_pods], %w(labels))
    # no taggings for build pods, they don't acts_as_miq_taggable.

    @collections[:persistent_volumes]       =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class    => PersistentVolume,
          :parent         => manager,
          :builder_params => {:parent_id => manager.id, :parent_type => manager.class.base_class},
          :association    => :persistent_volumes,
          :manager_ref    => [:parent_id, :parent_type, :ems_ref],
        )
      )
    @collections[:persistent_volume_claims] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class          => PersistentVolumeClaim,
          :parent               => manager,
          :builder_params       => {:ems_id => manager.id},
          :association          => :persistent_volume_claims,
          :secondary_refs       => {:by_container_project_and_name => [:container_project, :name]},
          :attributes_blacklist => [:namespace],
        )
      )
  end

  # ContainerCondition is polymorphic child of ContainerNode & ContainerGroup.
  def initialize_container_conditions_collection(manager, association)
    relation = manager.public_send(association)
    query = ContainerCondition.where(
      :container_entity_type => relation.model.base_class.name,
      :container_entity_id   => relation, # nested SELECT. TODO: compare to a JOIN.
    )
    @collections[[:container_conditions_for, relation.model.base_class.name]] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class => ContainerCondition,
          :name        => "container_conditions_for_#{association}".to_sym,
          :arel        => query,
          :manager_ref => [:container_entity, :name],
        )
      )
  end

  # CustomAttribute is polymorphic child of many models
  def initialize_custom_attributes_collections(parent_collection, sections)
    type = parent_collection.model_class.base_class.name
    relation = parent_collection.full_collection_for_comparison
    sections.each do |section|
      query = CustomAttribute.where(
        :resource_type => type,
        :resource_id   => relation,
        :section       => section.to_s
      )
      @collections[[:custom_attributes_for, type, section.to_s]] =
        ::ManagerRefresh::InventoryCollection.new(
          shared_options.merge(
            :model_class                  => CustomAttribute,
            :name                         => "custom_attributes_for_#{parent_collection.name}_#{section}".to_sym,
            :arel                         => query,
            :manager_ref                  => [:resource, :section, :name],
            :parent_inventory_collections => [parent_collection.name],
          )
        )
    end
  end

  def initialize_taggings_collection(parent_collection)
    type = parent_collection.model_class.base_class.name
    relation = parent_collection.full_collection_for_comparison
    query = Tagging.where(
      :taggable_type => type,
      :taggable_id   => relation,
    ).joins(:tag).merge(Tag.controlled_by_mapping)

    @collections[[:taggings_for, type]] =
      ::ManagerRefresh::InventoryCollection.new(
        shared_options.merge(
          :model_class                  => Tagging,
          :name                         => "taggings_for_#{parent_collection.name}".to_sym,
          :arel                         => query,
          :manager_ref                  => [:taggable, :tag],
          :parent_inventory_collections => [parent_collection.name],
        )
      )
  end

  def add_collection(collection)
    @collections[collection.name] = collection
  end

  def custom_reconnect_block
    # TODO(lsmola) once we have DB unique indexes, we can stop using manual reconnect, since it adds processing time
    lambda do |inventory_collection, inventory_objects_index, attributes_index|
      relation = inventory_collection.model_class.where(:ems_id => inventory_collection.parent.id).archived

      # Skip reconnect if there are no archived entities
      return if relation.archived.count <= 0
      raise "Allowed only manager_ref size of 1, got #{inventory_collection.manager_ref}" if inventory_collection.manager_ref.count > 1

      inventory_objects_index.each_slice(1000) do |batch|
        relation.where(inventory_collection.manager_ref.first => batch.map(&:first)).each do |record|
          index = inventory_collection.object_index_with_keys(inventory_collection.manager_ref_to_cols, record)

          # We need to delete the record from the inventory_objects_index and attributes_index, otherwise it
          # would be sent for create.
          inventory_object = inventory_objects_index.delete(index)
          hash             = attributes_index.delete(index)

          # Make the entity active again, otherwise we would be duplicating nested entities
          hash[:deleted_on] = nil

          record.assign_attributes(hash.except(:id, :type))
          if !inventory_collection.check_changed? || record.changed?
            record.save!
            inventory_collection.store_updated_records(record)
          end

          inventory_object.id = record.id
        end
      end
    end
    end
end
