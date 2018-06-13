class ManagerRefresh::InventoryCollectionDefault
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

  class << self
    def vms(extra_attributes = {})
      attributes = {
        :model_class                 => ::Vm,
        :association                 => :vms,
        :delete_method               => :disconnect_inv,
        :attributes_blacklist        => [:genealogy_parent],
        :use_ar_object               => true, # Because of raw_power_state setter and hooks are needed for settings user
        # TODO(lsmola) can't do batch strategy for vms because of key_pairs relation
        :saver_strategy              => :default,
        :batch_extra_attributes      => [:power_state, :state_changed_on, :previous_state],
        :inventory_object_attributes => [
          :type,
          :cpu_limit,
          :cpu_reserve,
          :cpu_reserve_expand,
          :cpu_shares,
          :cpu_shares_level,
          :ems_ref,
          :ems_ref_obj,
          :uid_ems,
          :connection_state,
          :vendor,
          :name,
          :location,
          :template,
          :memory_limit,
          :memory_reserve,
          :memory_reserve_expand,
          :memory_shares,
          :memory_shares_level,
          :raw_power_state,
          :boot_time,
          :host,
          :ems_cluster,
          :storages,
          :storage,
          :snapshots
        ],
        :builder_params              => {
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
        :model_class                 => ::MiqTemplate,
        :association                 => :miq_templates,
        :delete_method               => :disconnect_inv,
        :attributes_blacklist        => [:genealogy_parent],
        :use_ar_object               => true, # Because of raw_power_state setter
        :saver_strategy              => :default, # Hooks are needed for setting user
        :batch_extra_attributes      => [:power_state, :state_changed_on, :previous_state],
        :inventory_object_attributes => [
          :type,
          :ems_ref,
          :ems_ref_obj,
          :uid_ems,
          :connection_state,
          :vendor,
          :name,
          :location,
          :template,
          :memory_limit,
          :memory_reserve,
          :raw_power_state,
          :boot_time,
          :host,
          :ems_cluster,
          :storages,
          :storage,
          :snapshots
        ],
        :builder_params              => {
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
        :inventory_object_attributes  => [
          :annotation,
          :cpu_cores_per_socket,
          :cpu_sockets,
          :cpu_speed,
          :cpu_total_cores,
          :cpu_type,
          :guest_os,
          :manufacturer,
          :memory_mb,
          :model,
          :networks,
          :number_of_nics,
          :serial_number,
          :virtual_hw_version
        ],
        # TODO(lsmola) just because of default value on cpu_sockets, this can be fixed by separating instances_hardwares and images_hardwares
        :use_ar_object                => true,
      }

      attributes.merge!(extra_attributes)
    end

    def operating_systems(extra_attributes = {})
      attributes = {
        :model_class                  => ::OperatingSystem,
        :manager_ref                  => [:vm_or_template],
        :association                  => :operating_systems,
        :parent_inventory_collections => [:vms, :miq_templates],
        :inventory_object_attributes  => [
          :name,
          :product_name,
          :product_type,
          :system_type,
          :version
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def disks(extra_attributes = {})
      attributes = {
        :model_class                  => ::Disk,
        :manager_ref                  => [:hardware, :device_name],
        :association                  => :disks,
        :parent_inventory_collections => [:vms],
        :inventory_object_attributes  => [
          :device_name,
          :device_type,
          :controller_type,
          :present,
          :filename,
          :location,
          :size,
          :size_on_disk,
          :disk_type,
          :mode,
          :bootable,
          :storage
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def relationships(relationship_key, relationship_type, parent_type, association, extra_attributes = {})
      relationship_save_block = lambda do |_ems, inventory_collection|
        parents  = Hash.new { |h, k| h[k] = {} }
        children = Hash.new { |h, k| h[k] = {} }

        inventory_collection.dependency_attributes.each_value do |dependency_collections|
          next if dependency_collections.blank?

          dependency_collections.each do |collection|
            next if collection.blank?

            collection.data.each do |obj|
              parent = obj.data[relationship_key].try(&:load)
              next if parent.nil?

              parent_klass = parent.inventory_collection.model_class

              # Save the model_class and id of the parent for each child
              children[collection.model_class][obj.id] = [parent_klass, parent.id]

              # This will be populated later when looking up all the parent ids
              parents[parent_klass][parent.id] = nil
            end
          end
        end

        ActiveRecord::Base.transaction do
          # Lookup all of the parent records
          parents.each do |model_class, ids|
            model_class.find(ids.keys).each { |record| ids[record.id] = record }
          end

          # Loop through all children and assign parents
          children.each do |model_class, ids|
            child_records = model_class.find(ids.keys).index_by(&:id)

            ids.each do |id, parent_info|
              child = child_records[id]

              parent_klass, parent_id = parent_info
              parent = parents[parent_klass][parent_id]

              child.with_relationship_type(relationship_type) do
                prev_parent = child.parent(:of_type => parent_type)
                unless prev_parent == parent
                  prev_parent&.remove_child(child)
                  parent.add_child(child)
                end
              end
            end
          end
        end
      end

      attributes = {
        :association       => association,
        :custom_save_block => relationship_save_block,
      }
      attributes.merge!(extra_attributes)
    end
  end
end
