class ManagerRefresh::InventoryCollectionDefault::CloudManager < ManagerRefresh::InventoryCollectionDefault
  class << self
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

    def vm_and_template_labels(extra_attributes = {})
      # TODO(lsmola) make a generic CustomAttribute IC and move it to base class
      attributes = {
        :model_class                  => CustomAttribute,
        :association                  => :vm_and_template_labels,
        :manager_ref                  => [:resource, :name],
        :parent_inventory_collections => [:vms, :miq_templates],
        :inventory_object_attributes  => [
          :resource,
          :section,
          :name,
          :value,
          :source,
        ]
      }

      attributes.merge!(extra_attributes)
    end

    def networks(extra_attributes = {})
      attributes = {
        :model_class                  => ::Network,
        :manager_ref                  => [:hardware, :description],
        :association                  => :networks,
        :parent_inventory_collections => [:vms],
      }

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

      attributes.merge!(extra_attributes)
    end

    def orchestration_stacks_outputs(extra_attributes = {})
      attributes = {
        :model_class                  => ::OrchestrationStackOutput,
        :association                  => :orchestration_stacks_outputs,
        :parent_inventory_collections => [:orchestration_stacks],
      }

      attributes.merge!(extra_attributes)
    end

    def orchestration_stacks_parameters(extra_attributes = {})
      attributes = {
        :model_class                  => ::OrchestrationStackParameter,
        :association                  => :orchestration_stacks_parameters,
        :parent_inventory_collections => [:orchestration_stacks],
      }

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

    def snapshots(extra_attributes = {})
      attributes = {
        :model_class                  => ::Snapshot,
        :association                  => :snapshots,
        :manager_ref                  => [:vm_or_template, :ems_ref],
        :parent_inventory_collections => [:vms, :miq_templates],
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
      relationships(:genealogy_parent, :genealogy, nil, :vm_and_miq_template_ancestry, extra_attributes)
    end
  end
end
