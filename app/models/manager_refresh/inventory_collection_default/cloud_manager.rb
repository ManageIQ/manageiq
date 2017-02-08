class ManagerRefresh::InventoryCollectionDefault::CloudManager < ManagerRefresh::InventoryCollectionDefault
  class << self
    def vms(extra_attributes = {})
      attributes = {
        :model_class          => ::ManageIQ::Providers::CloudManager::Vm,
        :association          => :vms,
        :attributes_blacklist => [:genealogy_parent]
      }

      attributes.merge!(extra_attributes)
    end

    def miq_templates(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::CloudManager::Template,
        :association => :miq_templates,
      }

      attributes.merge!(extra_attributes)
    end

    def availability_zones(extra_attributes = {})
      attributes = {
        :model_class => ::AvailabilityZone,
        :association => :availability_zones,
      }

      attributes.merge!(extra_attributes)
    end

    def flavors(extra_attributes = {})
      attributes = {
        :model_class => ::Flavor,
        :association => :flavors,
      }

      attributes.merge!(extra_attributes)
    end

    def key_pairs(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::CloudManager::AuthKeyPair,
        :manager_ref => [:name],
        :association => :key_pairs
      }

      attributes.merge!(extra_attributes)
    end

    def hardwares(extra_attributes = {})
      attributes = {
        :model_class => ::Hardware,
        :manager_ref => [:vm_or_template],
        :association => :hardwares
      }

      case extra_attributes[:strategy]
      when :local_db_cache_all
        attributes[:custom_manager_uuid] = lambda do |hardware|
          [hardware.vm_or_template.ems_ref]
        end
      when :find_missing_in_local_db
        attributes[:custom_db_finder] = lambda do |inventory_collection, hash_uuid_by_ref|
          inventory_collection.parent.send(inventory_collection.association).references(:vm_or_template).where(
            :vms => {:ems_ref => hash_uuid_by_ref[:vm_or_template]}
          ).first
        end
      end

      attributes.merge!(extra_attributes)
    end

    def disks(extra_attributes = {})
      attributes = {
        :model_class => ::Disk,
        :manager_ref => [:hardware, :device_name],
        :association => :disks
      }

      if extra_attributes[:strategy] == :local_db_cache_all
        attributes[:custom_manager_uuid] = lambda do |disk|
          [disk.hardware.vm_or_template.ems_ref, disk.device_name]
        end
      end

      attributes.merge!(extra_attributes)
    end

    def networks(extra_attributes = {})
      attributes = {
        :model_class => ::Network,
        :manager_ref => [:hardware, :description],
        :association => :networks
      }

      if extra_attributes[:strategy] == :local_db_cache_all
        attributes[:custom_manager_uuid] = lambda do |network|
          [network.hardware.vm_or_template.ems_ref, network.description]
        end
      end

      attributes.merge!(extra_attributes)
    end

    def orchestration_stacks(extra_attributes = {})
      attributes = {
        :model_class          => ::ManageIQ::Providers::CloudManager::OrchestrationStack,
        :association          => :orchestration_stacks,
        :attributes_blacklist => [:parent]
      }

      attributes.merge!(extra_attributes)
    end

    def orchestration_stacks_resources(extra_attributes = {})
      attributes = {
        :model_class => ::OrchestrationStackResource,
        :association => :orchestration_stacks_resources,
      }

      attributes.merge!(extra_attributes)
    end

    def orchestration_stacks_outputs(extra_attributes = {})
      attributes = {
        :model_class => ::OrchestrationStackOutput,
        :association => :orchestration_stacks_outputs,
      }

      attributes.merge!(extra_attributes)
    end

    def orchestration_stacks_parameters(extra_attributes = {})
      attributes = {
        :model_class => ::OrchestrationStackParameter,
        :association => :orchestration_stacks_parameters,
      }

      attributes.merge!(extra_attributes)
    end

    def orchestration_templates(extra_attributes = {})
      # TODO(lsmola) do refactoring, we shouldn't need this custom saving block
      orchestration_template_save_block = lambda do |_ems, inventory_collection|
        hashes = inventory_collection.data.map(&:attributes)

        templates = ::OrchestrationTemplate.find_or_create_by_contents(hashes)
        inventory_collection.data.zip(templates).each do |inventory_object, template|
          inventory_object.id = template.id
        end
      end

      attributes = {
        :model_class       => ::OrchestrationTemplateCfn,
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
          parent_id = x.data[:parent].load.try(:id)
          obj[x.id] = parent_id if parent_id
        end

        model_class = stacks_inventory_collection.model_class

        stacks_parents_indexed = model_class
                                 .select([:id, :ancestry])
                                 .where(:id => stacks_parents.values).find_each.index_by(&:id)

        model_class
          .select([:id, :ancestry])
          .where(:id => stacks_parents.keys).find_each do |stack|
          parent = stacks_parents_indexed[stacks_parents[stack.id]]
          stack.update_attribute(:parent, parent)
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
        vms_inventory_collection = inventory_collection.dependency_attributes[:vms].try(:first)
        miq_templates_inventory_collection = inventory_collection.dependency_attributes[:miq_templates].try(:first)

        return if vms_inventory_collection.blank? || miq_templates_inventory_collection.blank?

        # Fetch IDs of all vms and genealogy_parents, only if genealogy_parent is present
        vms_genealogy_parents = inventory_collection.dependency_attributes[:vms].first.data.each_with_object({}) do |x, obj|
          genealogy_parent_id = x.data[:genealogy_parent].load.try(:id)
          obj[x.id]           = genealogy_parent_id if genealogy_parent_id
        end

        miq_templates = miq_templates_inventory_collection.model_class
                                                          .select([:id])
                                                          .where(:id => vms_genealogy_parents.values).find_each.index_by(&:id)

        vms_inventory_collection.model_class
                                .select([:id])
                                .where(:id => vms_genealogy_parents.keys).find_each do |vm|
          parent = miq_templates[vms_genealogy_parents[vm.id]]
          parent.with_relationship_type('genealogy') { parent.set_child(vm) }
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
