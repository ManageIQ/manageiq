class ManagerRefresh::InventoryCollectionDefault::CloudManager < ManagerRefresh::InventoryCollectionDefault
  class << self
    def vms(extra_attributes = {})
      attributes = {
        :model_class            => ::ManageIQ::Providers::CloudManager::Vm,
        :association            => :vms,
        :delete_method          => :disconnect_inv,
        :attributes_blacklist   => [:genealogy_parent],
        :use_ar_object          => true, # Because of raw_power_state setter and hooks are needed for settings user
        # TODO(lsmola) can't do batch strategy for vms because of key_pairs relation
        :saver_strategy         => :default,
        :batch_extra_attributes => [:power_state, :state_changed_on, :previous_state],
        :builder_params         => {
          :ems_id   => ->(persister) { persister.manager.id },
          :name     => "unknown",
          :location => "unknown",
        }
      }

      attributes.merge!(extra_attributes)
    end

    def miq_templates(extra_attributes = {})
      attributes = {
        :model_class            => ::ManageIQ::Providers::CloudManager::Template,
        :association            => :miq_templates,
        :delete_method          => :disconnect_inv,
        :attributes_blacklist   => [:genealogy_parent],
        :use_ar_object          => true, # Because of raw_power_state setter
        :saver_strategy         => :default, # Hooks are needed for setting user
        :batch_extra_attributes => [:power_state, :state_changed_on, :previous_state],
        :builder_params         => {
          :ems_id   => ->(persister) { persister.manager.id },
          :name     => "unknown",
          :location => "unknown",
          :template => true
        }
      }

      attributes.merge!(extra_attributes)
    end

    def availability_zones(extra_attributes = {})
      attributes = {
        :model_class    => ::AvailabilityZone,
        :association    => :availability_zones,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def flavors(extra_attributes = {})
      attributes = {
        :model_class    => ::Flavor,
        :association    => :flavors,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def key_pairs(extra_attributes = {})
      attributes = {
        :model_class    => ::ManageIQ::Providers::CloudManager::AuthKeyPair,
        :manager_ref    => [:name],
        :association    => :key_pairs,
        :builder_params => {
          :resource_id   => ->(persister) { persister.manager.id },
          :resource_type => ->(persister) { persister.manager.class.base_class },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def hardwares(extra_attributes = {})
      attributes = {
        :model_class                  => ::Hardware,
        :manager_ref                  => [:vm_or_template],
        :association                  => :hardwares,
        :parent_inventory_collections => [:vms, :miq_templates],
        # TODO(lsmola) just because of default value on cpu_sockets, this can be fixed by separating instances_hardwares and images_hardwares
        :use_ar_object                => true,
      }

      attributes[:custom_manager_uuid] = lambda do |hardware|
        [hardware.vm_or_template.ems_ref]
      end

      attributes[:custom_db_finder] = lambda do |inventory_collection, selection, _projection|
        relation = inventory_collection.parent.send(inventory_collection.association)
                                       .includes(:vm_or_template)
                                       .references(:vm_or_template)
        relation = relation.where(:vms => {:ems_ref => selection.map { |x| x[:vm_or_template] }}) unless selection.blank?
        relation
      end

      attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.hardwares.joins(:vm_or_template).where(
          'vms' => {:ems_ref => manager_uuids}
        )
      end

      attributes.merge!(extra_attributes)
    end

    def disks(extra_attributes = {})
      attributes = {
        :model_class                  => ::Disk,
        :manager_ref                  => [:hardware, :device_name],
        :association                  => :disks,
        :parent_inventory_collections => [:vms],
      }

      if extra_attributes[:strategy] == :local_db_cache_all
        attributes[:custom_manager_uuid] = lambda do |disk|
          [disk.hardware.vm_or_template.ems_ref, disk.device_name]
        end
      end

      attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.disks.joins(:hardware => :vm_or_template).where(
          :hardware => {'vms' => {:ems_ref => manager_uuids}}
        )
      end

      attributes.merge!(extra_attributes)
    end

    def networks(extra_attributes = {})
      attributes = {
        :model_class                  => ::Network,
        :manager_ref                  => [:hardware, :description],
        :association                  => :networks,
        :parent_inventory_collections => [:vms],
      }

      attributes[:custom_manager_uuid] = lambda do |network|
        [network.hardware.vm_or_template.ems_ref, network.description]
      end

      attributes[:custom_db_finder] = lambda do |inventory_collection, selection, _projection|
        relation = inventory_collection.parent.send(inventory_collection.association)
                                       .joins(:hardware => :vm_or_template)
                                       .references(:hardware => :vm_or_template)

        unless selection.blank?
          vms_ems_refs = selection.map { |x| x[:hardware] }.uniq
          descriptions = selection.map { |x| x[:description] }.uniq

          relation = relation.where(:hardware => {'vms' => {:ems_ref => vms_ems_refs}})
          relation = relation.where(:description => descriptions)
        end
        relation
      end

      attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.networks.joins(:hardware => :vm_or_template).where(
          :hardware => {'vms' => {:ems_ref => manager_uuids}}
        )
      end

      attributes.merge!(extra_attributes)
    end

    def orchestration_stacks(extra_attributes = {})
      attributes = {
        :model_class          => ::ManageIQ::Providers::CloudManager::OrchestrationStack,
        :association          => :orchestration_stacks,
        :attributes_blacklist => [:parent],
        :builder_params       => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def orchestration_stacks_resources(extra_attributes = {})
      attributes = {
        :model_class                  => ::OrchestrationStackResource,
        :association                  => :orchestration_stacks_resources,
        :parent_inventory_collections => [:orchestration_stacks]
      }

      extra_attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.orchestration_stacks_resources.references(:orchestration_stacks).where(
          :orchestration_stacks => {:ems_ref => manager_uuids}
        )
      end

      attributes.merge!(extra_attributes)
    end

    def orchestration_stacks_outputs(extra_attributes = {})
      attributes = {
        :model_class                  => ::OrchestrationStackOutput,
        :association                  => :orchestration_stacks_outputs,
        :parent_inventory_collections => [:orchestration_stacks],
      }

      extra_attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.orchestration_stacks_outputs.references(:orchestration_stacks).where(
          :orchestration_stacks => {:ems_ref => manager_uuids}
        )
      end

      attributes.merge!(extra_attributes)
    end

    def orchestration_stacks_parameters(extra_attributes = {})
      attributes = {
        :model_class                  => ::OrchestrationStackParameter,
        :association                  => :orchestration_stacks_parameters,
        :parent_inventory_collections => [:orchestration_stacks],
      }

      extra_attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.orchestration_stacks_parameters.references(:orchestration_stacks).where(
          :orchestration_stacks => {:ems_ref => manager_uuids}
        )
      end

      attributes.merge!(extra_attributes)
    end

    def orchestration_templates(extra_attributes = {})
      # TODO(lsmola) do refactoring, we shouldn't need this custom saving block
      orchestration_template_save_block = lambda do |_ems, inventory_collection|
        hashes = inventory_collection.data.map(&:attributes)

        templates = inventory_collection.model_class.find_or_create_by_contents(hashes)
        inventory_collection.data.zip(templates).each do |inventory_object, template|
          inventory_object.id = template.id
        end
      end

      attributes = {
        :model_class       => ::OrchestrationTemplate,
        :association       => :orchestration_templates,
        :custom_save_block => orchestration_template_save_block
      }

      attributes.merge!(extra_attributes)
    end

    def orchestration_stack_ancestry(extra_attributes = {})
      orchestration_stack_ancestry_save_block = lambda do |_ems, inventory_collection|
        stacks_inventory_collection = inventory_collection.dependency_attributes[:orchestration_stacks].try(:first)

        return if stacks_inventory_collection.blank?

        stacks_parents = stacks_inventory_collection.data.each_with_object({}) do |x, obj|
          parent_id = x.data[:parent].try(:load).try(:id)
          obj[x.id] = parent_id if parent_id
        end

        model_class = stacks_inventory_collection.model_class

        stacks_parents_indexed = model_class
                                 .select([:id, :ancestry])
                                 .where(:id => stacks_parents.values).find_each.index_by(&:id)

        ActiveRecord::Base.transaction do
          model_class.select([:id, :ancestry])
                     .where(:id => stacks_parents.keys).find_each do |stack|
            parent = stacks_parents_indexed[stacks_parents[stack.id]]
            stack.update_attribute(:parent, parent)
          end
        end
      end

      attributes = {
        :association       => :orchestration_stack_ancestry,
        :custom_save_block => orchestration_stack_ancestry_save_block
      }
      attributes.merge!(extra_attributes)
    end

    def vm_and_miq_template_ancestry(extra_attributes = {})
      vm_and_miq_template_ancestry_save_block = lambda do |_ems, inventory_collection|
        vms_inventory_collection           = inventory_collection.dependency_attributes[:vms].try(:first)
        miq_templates_inventory_collection = inventory_collection.dependency_attributes[:miq_templates].try(:first)

        return if vms_inventory_collection.blank? || miq_templates_inventory_collection.blank?

        # Fetch IDs of all vms and genealogy_parents, only if genealogy_parent is present
        vms_genealogy_parents = vms_inventory_collection.data.each_with_object({}) do |x, obj|
          unless x.data[:genealogy_parent].nil?
            genealogy_parent_id = x.data[:genealogy_parent].load.try(:id)
            obj[x.id]           = genealogy_parent_id if genealogy_parent_id
          end
        end

        miq_template_genealogy_parents = miq_templates_inventory_collection.data.each_with_object({}) do |x, obj|
          unless x.data[:genealogy_parent].nil?
            genealogy_parent_id = x.data[:genealogy_parent].load.try(:id)
            obj[x.id]           = genealogy_parent_id if genealogy_parent_id
          end
        end

        ActiveRecord::Base.transaction do
          # associate parent templates to child instances
          parent_miq_templates = miq_templates_inventory_collection.model_class
                                                                   .select([:id])
                                                                   .where(:id => vms_genealogy_parents.values).find_each.index_by(&:id)
          vms_inventory_collection.model_class
                                  .select([:id])
                                  .where(:id => vms_genealogy_parents.keys).find_each do |vm|
            parent = parent_miq_templates[vms_genealogy_parents[vm.id]]
            vm.with_relationship_type('genealogy') { vm.parent = parent }
          end
        end

        ActiveRecord::Base.transaction do
          # associate parent instances to child templates
          parent_vms = vms_inventory_collection.model_class
                                               .select([:id])
                                               .where(:id => miq_template_genealogy_parents.values).find_each.index_by(&:id)
          miq_templates_inventory_collection.model_class
                                            .select([:id])
                                            .where(:id => miq_template_genealogy_parents.keys).find_each do |miq_template|
            parent = parent_vms[miq_template_genealogy_parents[miq_template.id]]
            miq_template.with_relationship_type('genealogy') { miq_template.parent = parent }
          end
        end
      end

      attributes = {
        :association       => :vm_and_miq_template_ancestry,
        :custom_save_block => vm_and_miq_template_ancestry_save_block,
      }
      attributes.merge!(extra_attributes)
    end
  end
end
