module ManageIQ::Providers
  class Inventory::Persister
    class Builder
      class CloudManager < ::ManageIQ::Providers::Inventory::Persister::Builder
        def availability_zones
          add_common_default_values
        end

        def cloud_tenants
          add_common_default_values
        end

        def cloud_resource_quotas
          add_common_default_values
        end

        def cloud_services
          add_common_default_values
        end

        def cloud_volumes
          add_common_default_values
        end

        def flavors
          add_common_default_values
        end

        def host_aggregates
          add_common_default_values
        end

        def auth_key_pairs
          add_properties(
            :name        => :auth_key_pairs,
            :association => :key_pairs,
            :manager_ref => %i[name]
          )
          add_default_values(
            :resource_id   => parent.id,
            :resource_type => parent.class.base_class
          )
        end

        def cloud_database_flavors
          add_common_default_values
        end

        def cloud_databases
          add_common_default_values
        end

        def resource_groups
          add_common_default_values
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
