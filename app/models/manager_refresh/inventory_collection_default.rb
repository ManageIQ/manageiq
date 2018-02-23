class ManagerRefresh::InventoryCollectionDefault
  INVENTORY_RECONNECT_BLOCK = lambda do |inventory_collection, inventory_objects_index, attributes_index|
    relation = inventory_collection.model_class.where(:ems_id => nil)

    return if relation.count <= 0

    inventory_objects_index.each_slice(100) do |batch|
      batch_refs = batch.map(&:first)
      relation.where(inventory_collection.manager_ref.first => batch_refs).each do |record|
        index = inventory_collection.object_index_with_keys(inventory_collection.manager_ref_to_cols, record)

        # We need to delete the record from the inventory_objects_index
        # and attributes_index, otherwise it would be sent for create.
        inventory_object = inventory_objects_index.delete(index)
        hash             = attributes_index.delete(index)

        record.assign_attributes(hash.except(:id, :type))
        if !inventory_collection.check_changed? || record.changed?
          record.save!
          inventory_collection.store_updated_records(record)
        end

        inventory_object.id = record.id
      end
    end
  end.freeze

  class << self
    def vms(extra_attributes = {})
      attributes = {
        :model_class            => ::Vm,
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
        },
        :custom_reconnect_block      => INVENTORY_RECONNECT_BLOCK,
      }

      attributes.merge!(extra_attributes)
    end

    def miq_templates(extra_attributes = {})
      attributes = {
        :model_class            => ::MiqTemplate,
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
        },
        :custom_reconnect_block      => INVENTORY_RECONNECT_BLOCK,
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

    def operating_systems(extra_attributes = {})
      attributes = {
        :model_class                  => ::OperatingSystem,
        :manager_ref                  => [:vm_or_template],
        :association                  => :operating_systems,
        :parent_inventory_collections => [:vms, :miq_templates],
      }

      attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.operating_systems.joins(:vm_or_template).where(
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
  end
end
