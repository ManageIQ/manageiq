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

        def key_pairs
          add_properties(
            :model_class => ::ManageIQ::Providers::CloudManager::AuthKeyPair,
            :manager_ref => %i(name)
          )
          add_default_values(
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
            :manager_ref                  => %i(taggable tag),
            :parent_inventory_collections => %i(vms miq_templates)
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
