module ManageIQ::Providers::Inventory::Persister::Builder::Shared
  extend ActiveSupport::Concern

  included do
    INVENTORY_RECONNECT_BLOCK = lambda do |inventory_collection, inventory_objects_index, attributes_index|
      relation = inventory_collection.model_class.where(:ems_id => nil)

      return if relation.count <= 0

      inventory_objects_index.each_slice(100) do |batch|
        batch_refs = batch.map(&:first)
        relation.where(inventory_collection.manager_ref.first => batch_refs).order(:id => :asc).each do |record|
          index = inventory_collection.object_index_with_keys(inventory_collection.manager_ref_to_cols, record)

          # We need to delete the record from the inventory_objects_index
          # and attributes_index, otherwise it would be sent for create.
          inventory_object = inventory_objects_index.delete(index)
          hash             = attributes_index.delete(index)

          # Skip if hash is blank, which can happen when having several archived entities with the same ref
          next unless hash

          record.assign_attributes(hash.except(:id, :type))
          if !inventory_collection.check_changed? || record.changed?
            record.save!
            inventory_collection.store_updated_records(record)
          end

          inventory_object.id = record.id
        end
      end
    end.freeze

    def vendor
      ::ManageIQ::Providers::Inflector.provider_name(@persister_class).downcase
    rescue
      'unknown'
    end

    def ext_management_system
      add_properties(
        :manager_ref       => %i(guid),
        :custom_save_block => lambda do |ems, inventory_collection|
          ems_attrs = inventory_collection.data.first&.attributes
          ems.update!(ems_attrs) if ems_attrs
        end
      )
    end

    def vms
      vm_template_shared
    end

    def miq_templates
      vm_template_shared
      add_default_values(
        :template => true
      )
    end

    def vm_template_shared
      add_properties(
        :delete_method          => :disconnect_inv,
        :attributes_blacklist   => %i[genealogy_parent parent resource_pool],
        :use_ar_object          => true, # Because of raw_power_state setter and hooks are needed for settings user
        :saver_strategy         => :default,
        :batch_extra_attributes => %i(power_state state_changed_on previous_state),
        :custom_reconnect_block => INVENTORY_RECONNECT_BLOCK
      )

      add_default_values(
        :ems_id => ->(persister) { persister.manager.id }
      )
    end

    def vm_and_template_labels
      # TODO(lsmola) make a generic CustomAttribute IC and move it to base class
      add_properties(
        :model_class                  => ::CustomAttribute,
        :manager_ref                  => %i[resource name],
        :parent_inventory_collections => %i[vms miq_templates]
      )

      add_targeted_arel(
        lambda do |inventory_collection|
          manager_uuids = inventory_collection.parent_inventory_collections.collect(&:manager_uuids).map(&:to_a).flatten
          inventory_collection.parent.vm_and_template_labels.where(
            'vms' => {:ems_ref => manager_uuids}
          )
        end
      )
    end

    def vm_and_template_taggings
      add_properties(
        :model_class                  => Tagging,
        :manager_ref                  => %i[taggable tag],
        :parent_inventory_collections => %i[vms miq_templates]
      )

      add_targeted_arel(
        lambda do |inventory_collection|
          manager_uuids = inventory_collection.parent_inventory_collections.collect(&:manager_uuids).map(&:to_a).flatten
          ems = inventory_collection.parent
          ems.vm_and_template_taggings.where(
            'taggable_id' => ems.vms_and_templates.where(:ems_ref => manager_uuids)
          )
        end
      )
    end

    def hardwares
      add_properties(
        :manager_ref                  => %i(vm_or_template),
        :parent_inventory_collections => %i(vms miq_templates),
        :use_ar_object                => true, # TODO(lsmola) just because of default value on cpu_sockets, this can be fixed by separating instances_hardwares and images_hardwares
      )
    end

    def operating_systems
      custom_save_block = lambda do |_ems, inventory_collection|
        vms_and_templates_ids   = inventory_collection.data.map { |os| os.vm_or_template&.id }.compact
        vms_and_templates_index = VmOrTemplate.includes(:operating_system).where(:id => vms_and_templates_ids).index_by(&:id)

        drift_states = DriftState.where(:resource_type => "VmOrTemplate", :resource_id => vms_and_templates_ids)
                                 .select(:resource_id).distinct.index_by(&:resource_id)

        inventory_collection.each do |inventory_object|
          vm_or_template = vms_and_templates_index[inventory_object.vm_or_template.id]

          # If a VM has had smartstate run on it (drift_states are present) then don't overwrite the
          # operating system record with one from the provider.  This is because typically far more
          # details and correct information can be found from smartstate.
          next unless drift_states[vm_or_template.id].nil? || vm_or_template.operating_system.nil? ||
                      vm_or_template.operating_system.product_name.blank?

          operating_system = vm_or_template.operating_system || inventory_object.model_class.new
          operating_system.update!(inventory_object.attributes)
        end
      end

      add_properties(
        :manager_ref                  => %i(vm_or_template),
        :parent_inventory_collections => %i(vms miq_templates),
        :custom_save_block            => custom_save_block
      )
    end

    def networks
      add_properties(
        :manager_ref                  => %i(hardware description),
        :parent_inventory_collections => %i(vms)
      )
    end

    def disks
      add_properties(
        :manager_ref                  => %i(hardware device_name),
        :parent_inventory_collections => %i(vms)
      )
    end

    def service_offerings
      add_common_default_values
    end

    def service_instances
      add_common_default_values
    end

    def service_parameters_sets
      add_common_default_values
    end

    def orchestration_stacks
      add_properties(
        :attributes_blacklist => %i(parent),
      )

      add_common_default_values
    end

    protected

    def add_common_default_values
      add_default_values(:ems_id => ->(persister) { persister.manager.id })
    end

    def relationship_save_block(relationship_key:, relationship_type: :ems_metadata, parent_type: nil)
      lambda do |_ems, inventory_collection|
        children_by_parent = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = [] } }
        parent_by_child    = Hash.new { |h, k| h[k] = {} }

        dependency_collections = inventory_collection.dependency_attributes.flat_map(&:last)
        dependency_collections.each do |collection|
          next if collection.blank?

          collection.data.each do |obj|
            parent = obj.data[relationship_key].try(&:load)
            next if parent.nil?

            parent_klass = parent.inventory_collection.model_class.base_class
            child_klass  = collection.model_class.base_class

            children_by_parent[parent_klass][parent.id] << [child_klass, obj.id]
            parent_by_child[collection.model_class][obj.id] = [parent_klass, parent.id]
          end
        end

        ActiveRecord::Base.transaction do
          child_recs = parent_by_child.each_with_object({}) do |(model_class, child_ids), hash|
            hash[model_class] = model_class.find(child_ids.keys).index_by(&:id)
          end

          children_to_remove = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = [] } }
          children_to_add    = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = [] } }

          parent_recs_needed = Hash.new { |h, k| h[k] = [] }

          child_recs.each do |model_class, children_by_id|
            children_by_id.each_value do |child|
              new_parent_klass, new_parent_id = parent_by_child[model_class][child.id]
              prev_parent = child.with_relationship_type(relationship_type) { child.parents(:of_type => parent_type)&.first }

              next if prev_parent && (prev_parent.class.base_class == new_parent_klass && prev_parent.id == new_parent_id)

              children_to_remove[prev_parent.class.base_class][prev_parent.id] << child if prev_parent
              children_to_add[new_parent_klass][new_parent_id] << child

              parent_recs_needed[prev_parent.class.base_class] << prev_parent.id if prev_parent
              parent_recs_needed[new_parent_klass] << new_parent_id
            end
          end

          parent_recs = parent_recs_needed.each_with_object({}) do |(model_class, parent_ids), hash|
            hash[model_class] = model_class.find(parent_ids.uniq)
          end

          parent_recs.each do |model_class, parents|
            parents.each do |parent|
              old_children = children_to_remove[model_class][parent.id]
              new_children = children_to_add[model_class][parent.id]

              parent.remove_children(old_children) if old_children.present?
              parent.add_children(new_children) if new_children.present?
            end
          end
        end
      end
    end
  end
end
