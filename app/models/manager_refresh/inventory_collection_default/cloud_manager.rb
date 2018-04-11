# frozen_string_literal: true

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

    def vm_and_template_taggings(extra_attributes = {})
      attributes = {
        :model_class                  => Tagging,
        :association                  => :vm_and_template_taggings,
        :manager_ref                  => %i(taggable tag).freeze,
        :inventory_object_attributes  => %i(taggable tag).freeze,
        :parent_inventory_collections => %i(vms miq_templates).freeze,
      }

      attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.collect(&:manager_uuids).map(&:to_a).flatten
        ems = inventory_collection.parent
        ems.vm_and_template_taggings.where(
          'taggable_id' => ems.vms_and_templates.where(:ems_ref => manager_uuids)
        )
      end

      attributes[:custom_reconnect_block] = lambda do |inventory_collection, inventory_objects_index, attributes_index|
        taggable_attributes = %i(taggable_id taggable_type).freeze
        manager_ref_cols = inventory_collection.manager_ref_to_cols

        attributes_index
          .values
          .group_by { |object_attributes| object_attributes.slice(*taggable_attributes) }
          .each do |taggable_ref, attributes_array|
            next unless (taggable_attributes - taggable_ref.keys).empty?

            tag_ids = attributes_array.map { |object_attributes| object_attributes[:tag_id] }.uniq.compact
            relation = inventory_collection.model_class.where(taggable_ref)

            relation.where.not(:tag_id => tag_ids).in_batches(&:destroy_all)

            relation.where(:tag_id => tag_ids).select(:id, *manager_ref_cols).find_each do |record|
              index = inventory_collection.object_index_with_keys(manager_ref_cols, record)
              inventory_object = inventory_objects_index.delete(index)
              inventory_object.id = record.id
              attributes_index.delete(index)
              inventory_collection.store_updated_records(record) unless inventory_collection.check_changed?
            end
          end
      end.freeze

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
