module ManageIQ::Providers
  class Inventory::Persister
    class Builder
      class CloudManager < ::ManageIQ::Providers::Inventory::Persister::Builder
        def availability_zones
          add_common_default_values
        end

        def flavors
          add_common_default_values
        end

        def auth_key_pairs
          add_properties(
            :name        => :auth_key_pairs,
            :association => :key_pairs,
            :manager_ref => %i(name)
          )
          add_default_values(
            :resource_id   => ->(persister) { persister.manager.id },
            :resource_type => ->(persister) { persister.manager.class.base_class }
          )
        end

        def cloud_database_flavors
          add_common_default_values
        end

        def cloud_databases
          add_common_default_values
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
          skip_auto_inventory_attributes
          skip_model_class

          add_properties(
            :custom_save_block => orchestration_stack_ancestry_save_block
          )

          add_dependency_attributes(
            :orchestration_stacks           => ->(persister) { [persister.collections[:orchestration_stacks]] },
            :orchestration_stacks_resources => ->(persister) { [persister.collections[:orchestration_stacks_resources]] }
          )
        end

        def vm_and_miq_template_ancestry
          skip_auto_inventory_attributes
          skip_model_class

          add_properties(
            :custom_save_block => vm_and_miq_template_ancestry_save_block
          )

          add_dependency_attributes(
            :vms           => ->(persister) { [persister.collections[:vms]] },
            :miq_templates => ->(persister) { [persister.collections[:miq_templates]] }
          )
        end
      end

      private

      def orchestration_stack_ancestry_save_block
        lambda do |_ems, inventory_collection|
          stacks_inventory_collection = inventory_collection.dependency_attributes[:orchestration_stacks].try(:first)

          return if stacks_inventory_collection.blank?

          stacks_parents = stacks_inventory_collection.data.each_with_object({}) do |x, obj|
            parent_id = x.data[:parent].try(:load).try(:id)
            obj[x.id] = parent_id if parent_id
          end

          model_class = stacks_inventory_collection.model_class

          stacks_parents_indexed = model_class.select(%i(id ancestry))
                                              .where(:id => stacks_parents.values).find_each.index_by(&:id)

          ActiveRecord::Base.transaction do
            model_class.select(%i(id ancestry))
                       .where(:id => stacks_parents.keys).find_each do |stack|
              parent = stacks_parents_indexed[stacks_parents[stack.id]]
              stack.update_attribute(:parent, parent)
            end
          end
        end
      end

      def vm_and_miq_template_ancestry_save_block
        lambda do |_ems, inventory_collection|
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
                                                                     .where(:id => vms_genealogy_parents.values).find_each.index_by(&:id)
            vms_inventory_collection.model_class
                                    .where(:id => vms_genealogy_parents.keys).find_each do |vm|
              vm.update!(:genealogy_parent => parent_miq_templates[vms_genealogy_parents[vm.id]])
            end
          end

          ActiveRecord::Base.transaction do
            # associate parent instances to child templates
            parent_vms = vms_inventory_collection.model_class
                                                 .where(:id => miq_template_genealogy_parents.values).find_each.index_by(&:id)
            miq_templates_inventory_collection.model_class
                                              .where(:id => miq_template_genealogy_parents.keys).find_each do |miq_template|
              miq_template.update!(:genealogy_parent => parent_vms[miq_template_genealogy_parents[miq_template.id]])
            end
          end
        end
      end
    end
  end
end
