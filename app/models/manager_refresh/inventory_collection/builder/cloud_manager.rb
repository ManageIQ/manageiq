module ManagerRefresh
  class InventoryCollection
    class Builder
      class CloudManager < ::ManagerRefresh::InventoryCollection::Builder
        def availability_zones
          shared_builder_params
        end

        def flavors
          shared_builder_params
        end

        def key_pairs
          add_properties(
            :model_class => ::ManageIQ::Providers::CloudManager::AuthKeyPair,
            :manager_ref => %i(name)
          )
          add_builder_params(
            :resource_id   => ->(persister) { persister.manager.id },
            :resource_type => ->(persister) { persister.manager.class.base_class }
          )
        end

        def vm_and_template_labels
          # TODO(lsmola) make a generic CustomAttribute IC and move it to base class
          add_properties(
            :model_class                  => ::CustomAttribute,
            :manager_ref                  => %i(resource name),
            :parent_inventory_collections => %i(vms miq_templates)
          )
        end

        def orchestration_stacks
          add_properties(
            :model_class          => ::ManageIQ::Providers::CloudManager::OrchestrationStack,
            :attributes_blacklist => %i(parent),
          )

          shared_builder_params
        end

        def orchestration_stacks_resources
          add_properties(
            :model_class                  => ::OrchestrationStackResource,
            :parent_inventory_collections => %i(orchestration_stacks)
          )
        end

        def orchestration_stacks_outputs
          add_properties(
            :model_class                  => ::OrchestrationStackOutput,
            :parent_inventory_collections => %i(orchestration_stacks)
          )
        end

        def orchestration_stacks_parameters
          add_properties(
            :model_class                  => ::OrchestrationStackParameter,
            :parent_inventory_collections => %i(orchestration_stacks)
          )
        end

        def orchestration_templates
          # TODO(lsmola) do refactoring, we shouldn't need this custom saving block\
          orchestration_templates_save_block = lambda do |_ems, inventory_collection|
            hashes = inventory_collection.data.map(&:attributes)

            templates = inventory_collection.model_class.find_or_create_by_contents(hashes)
            inventory_collection.data.zip(templates).each do |inventory_object, template|
              inventory_object.id = template.id
            end
          end

          add_properties(
            :custom_save_block => orchestration_templates_save_block
          )
        end

        def orchestration_stack_ancestry
          orchestration_stack_ancestry_save_block = lambda do |_ems, inventory_collection|
            stacks_inventory_collection = inventory_collection.dependency_attributes[:orchestration_stacks].try(:first)

            return if stacks_inventory_collection.blank?

            stacks_parents = stacks_inventory_collection.data.each_with_object({}) do |x, obj|
              parent_id = x.data[:parent].try(:load).try(:id)
              obj[x.id] = parent_id if parent_id
            end

            model_class = stacks_inventory_collection.model_class

            stacks_parents_indexed = model_class
                                     .select(%i(id ancestry))
                                     .where(:id => stacks_parents.values).find_each.index_by(&:id)

            ActiveRecord::Base.transaction do
              model_class.select(%i(id ancestry))
                         .where(:id => stacks_parents.keys).find_each do |stack|
                parent = stacks_parents_indexed[stacks_parents[stack.id]]
                stack.update_attribute(:parent, parent)
              end
            end
          end

          add_properties(
            :custom_save_block => orchestration_stack_ancestry_save_block
          )
        end

        def vm_and_miq_template_ancestry
          vm_and_miq_template_ancestry_save_block = lambda do |_ems, inventory_collection|
            vms_inventory_collection = inventory_collection.dependency_attributes[:vms].try(:first)
            miq_templates_inventory_collection = inventory_collection.dependency_attributes[:miq_templates].try(:first)

            return if vms_inventory_collection.blank? || miq_templates_inventory_collection.blank?

            # Fetch IDs of all vms and genealogy_parents, only if genealogy_parent is present
            vms_genealogy_parents = vms_inventory_collection.data.each_with_object({}) do |x, obj|
              unless x.data[:genealogy_parent].nil?
                genealogy_parent_id = x.data[:genealogy_parent].load.try(:id)
                obj[x.id] = genealogy_parent_id if genealogy_parent_id
              end
            end

            miq_template_genealogy_parents = miq_templates_inventory_collection.data.each_with_object({}) do |x, obj|
              unless x.data[:genealogy_parent].nil?
                genealogy_parent_id = x.data[:genealogy_parent].load.try(:id)
                obj[x.id] = genealogy_parent_id if genealogy_parent_id
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

          add_properties(
            :custom_save_block => vm_and_miq_template_ancestry_save_block
          )
        end
      end

      private

      def shared_builder_params
        add_builder_params(:ems_id => default_ems_id)
      end

      def default_ems_id
        ->(persister) { persister.manager.id }
      end
    end
  end
end
