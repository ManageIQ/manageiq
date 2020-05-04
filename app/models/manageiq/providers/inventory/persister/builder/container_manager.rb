module ManageIQ::Providers
  class Inventory::Persister
    class Builder
      class ContainerManager < ::ManageIQ::Providers::Inventory::Persister::Builder
        # TODO: (agrare) Targeted refreshes will require adjusting the associations / arels. (duh)
        def container_projects
          add_properties(
            :secondary_refs => {:by_name => %i(name)},
            :delete_method  => :disconnect_inv
          )
          add_common_default_values
        end

        def container_quotas
          add_properties(
            :attributes_blacklist => %i(namespace),
            :delete_method        => :disconnect_inv
          )
          add_common_default_values
        end

        def container_quota_scopes
          add_properties(
            :manager_ref                  => %i(container_quota scope),
            :parent_inventory_collections => %i(container_quotas)
          )
        end

        def container_quota_items
          add_properties(
            :manager_ref                  => %i(container_quota resource quota_desired quota_enforced quota_observed),
            :delete_method                => :disconnect_inv,
            :parent_inventory_collections => %i(container_quotas)
          )
        end

        def container_limits
          add_properties(
            :attributes_blacklist => %i(namespace)
          )
          add_common_default_values
        end

        def container_limit_items
          add_properties(
            :manager_ref                  => %i(container_limit resource item_type),
            :parent_inventory_collections => %i(container_limits)
          )
        end

        def container_nodes
          add_properties(
            :model_class    => ::ContainerNode,
            :secondary_refs => {:by_name => %i(name)},
            :delete_method  => :disconnect_inv
          )
          add_common_default_values
        end

        def computer_systems
          add_properties(
            :manager_ref => %i(managed_entity),
            # TODO(lsmola) can we introspect this from the relation? Basically, the
            # :parent_inventory_collections are needed only if :association goes :through other association. Then the
            # parent is actually the root association (if we chain several :through associations). We should be able to
            # create a tree of :through associations of ems and infer the parent_inventory_collections from that?
            :parent_inventory_collections => %i(container_nodes),
          )
        end

        def computer_system_hardwares
          add_properties(
            :model_class                  => ::Hardware,
            :manager_ref                  => %i(computer_system),
            :parent_inventory_collections => %i(container_nodes),
          )
        end

        def computer_system_operating_systems
          add_properties(
            :model_class                  => ::OperatingSystem,
            :manager_ref                  => %i(computer_system),
            :parent_inventory_collections => %i(container_nodes),
          )
        end

        # images have custom_attributes but that's done conditionally in openshift parser
        def container_images
          add_properties(
            # TODO: (bpaskinc) old save matches on [:image_ref, :container_image_registry_id]
            # TODO: (bpaskinc) should match on digest when available
            # TODO: (mslemr) provider-specific class exists (openshift), but specs fail with them (?)
            :model_class            => ::ContainerImage,
            :manager_ref            => %i(image_ref),
            :delete_method          => :disconnect_inv,
            :custom_reconnect_block => custom_reconnect_block
          )
          add_common_default_values
        end

        def container_image_registries
          add_properties(:manager_ref => %i(host port))
          add_common_default_values
        end

        def container_groups
          add_properties(
            :model_class            => ContainerGroup,
            :secondary_refs         => {:by_container_project_and_name => %i(container_project name)},
            :attributes_blacklist   => %i(namespace),
            :delete_method          => :disconnect_inv,
            :custom_reconnect_block => custom_reconnect_block
          )
          add_common_default_values
        end

        def container_volumes
          add_properties(
            :manager_ref                  => %i(parent name),
            :parent_inventory_collections => %i(container_groups),
          )
        end

        def containers
          add_properties(
            :model_class            => Container,
            # parser sets :ems_ref => "#{pod_id}_#{container.name}_#{container.image}"
            :delete_method          => :disconnect_inv,
            :custom_reconnect_block => custom_reconnect_block
          )
          add_common_default_values
        end

        def container_port_configs
          # parser sets :ems_ref => "#{pod_id}_#{container_name}_#{port_config.containerPort}_#{port_config.hostPort}_#{port_config.protocol}"
          add_properties(
            :parent_inventory_collections => %i(containers)
          )
        end

        def container_env_vars
          add_properties(
            # TODO: (agrare) old save matches on all :name, :value, :field_path - does this matter?
            :manager_ref                  => %i(container name),
            :parent_inventory_collections => %i(containers)
          )
        end

        def security_contexts
          add_properties(
            :manager_ref                  => %i(resource),
            :parent_inventory_collections => %i(containers)
          )
        end

        def container_replicators
          add_properties(
            :secondary_refs       => {:by_container_project_and_name => %i(container_project name)},
            :attributes_blacklist => %i(namespace)
          )
          add_common_default_values
        end

        def container_services
          add_properties(
            :secondary_refs       => {:by_container_project_and_name => %i(container_project name)},
            :attributes_blacklist => %i(namespace),
            :saver_strategy       => "default" # TODO: (fryguy) (perf) Can't use batch strategy because of usage of M:N container_groups relation
          )
          add_common_default_values
        end

        def container_service_port_configs
          add_properties(
            :manager_ref                  => %i(ems_ref protocol), # TODO: (lsmola) make protocol part of the ems_ref?)
            :parent_inventory_collections => %i(container_services)
          )
        end

        def container_routes
          add_properties(
            :attributes_blacklist => %i(namespace)
          )
          add_common_default_values
        end

        def container_templates
          add_properties(
            :model_class          => ::ContainerTemplate,
            :attributes_blacklist => %i(namespace)
          )
          add_common_default_values
        end

        def container_template_parameters
          add_properties(
            :manager_ref                  => %i(container_template name),
            :parent_inventory_collections => %i(container_templates)
          )
        end

        def container_builds
          add_properties(
            :secondary_refs => {:by_namespace_and_name => %i(namespace name)}
          )
          add_common_default_values
        end

        def container_build_pods
          add_properties(
            # TODO: (bpaskinc) convert namespace column -> container_project_id?
            :manager_ref    => %i(namespace name),
            :secondary_refs => {:by_namespace_and_name => %i(namespace name)},
          )
          add_common_default_values
        end

        def persistent_volumes
          add_default_values(:parent => ->(persister) { persister.manager })
        end

        def persistent_volume_claims
          add_properties(
            :secondary_refs       => {:by_container_project_and_name => %i(container_project name)},
            :attributes_blacklist => %i(namespace)
          )
          add_common_default_values
        end

        def container_project_creation_events
          skip_auto_inventory_attributes
          skip_model_class
          add_properties(:custom_save_block => raise_creation_events_block)
          add_dependency_attributes(:container_projects => ->(p) { [p.collections[:container_projects]] })
        end

        def container_images_creation_events
          skip_auto_inventory_attributes
          skip_model_class
          add_properties(:custom_save_block => raise_creation_events_block)
          add_dependency_attributes(:container_images => ->(p) { [p.collections[:container_images]] })
        end

        def raise_creation_events_block
          lambda do |_manager, inventory_collection|
            saved_collections = inventory_collection.dependency_attributes.values.map(&:first)
            saved_collections.each do |saved_collection|
              next unless saved_collection.saver_strategy == :batch

              batch_size = 100
              saved_collection.created_records.each_slice(batch_size) do |batch|
                collection_ids = batch.collect { |x| x[:id] }
                MiqQueue.submit_job(
                  :class_name  => saved_collection.model_class.to_s,
                  :method_name => 'raise_creation_events',
                  :args        => [collection_ids],
                  :priority    => MiqQueue::HIGH_PRIORITY
                )
              end
            end
          end
        end

        protected

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

                # Skip if hash is blank, which can happen when having several archived entities with the same ref
                next unless hash

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
    end
  end
end
