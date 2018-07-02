module ManagerRefresh
  class InventoryCollection
    class Builder
      class InfraManager < ::ManagerRefresh::InventoryCollection::Builder
        def networks
          add_properties(
            :manager_ref => %i(hardware ipaddress ipv6address)
          )
        end

        def host_networks
          add_properties(
            :model_class                  => ::Network,
            :manager_ref                  => %i(hardware ipaddress),
            :parent_inventory_collections => %i(hosts)
          )
        end

        def guest_devices
          add_properties(
            :manager_ref => %i(hardware uid_ems),
          )
        end

        def host_hardwares
          add_properties(
            :model_class                  => ::Hardware,
            :manager_ref                  => %i(host),
            :parent_inventory_collections => %i(hosts)
          )
        end

        def snapshots
          add_properties(
            :manager_ref => %i(uid)
          )
        end

        def operating_systems
          add_properties(
            :manager_ref => %i(vm_or_template)
          )
        end

        def host_operating_systems
          add_properties(
            :model_class                  => ::OperatingSystem,
            :manager_ref                  => %i(host),
            :parent_inventory_collections => %i(hosts),
          )
        end

        def custom_attributes
          add_properties(
            :manager_ref => %i(name)
          )
        end

        def vm_and_template_ems_custom_fields
          @options[:auto_inventory_attributes] = false

          add_properties(
            :model_class => ::CustomAttribute,
            :manager_ref => %i(name)
          )

          add_inventory_attributes(%i(section name value source resource))
        end

        def ems_folders
          add_properties(
            :manager_ref          => %i(uid_ems),
            :attributes_blacklist => %i(ems_children),
          )
          add_common_default_values
        end

        def datacenters
          add_common_default_values
        end

        def resource_pools
          add_properties(
            :manager_ref          => %i(uid_ems),
            :attributes_blacklist => %i(ems_children),
          )
          add_common_default_values
        end

        def ems_clusters
          add_properties(
            :attributes_blacklist => %i(ems_children datacenter_id),
          )

          add_inventory_attributes(%i(datacenter_id))
          add_common_default_values
        end

        def storages
          add_properties(
            :manager_ref => %i(location),
            :complete    => false,
            :arel        => Storage,
          )
        end

        def hosts
          add_common_default_values

          add_custom_reconnect_block(
            lambda do |inventory_collection, inventory_objects_index, attributes_index|
              relation = inventory_collection.model_class.where(:ems_id => nil)

              return if relation.count <= 0

              inventory_objects_index.each_slice(100) do |batch|
                relation.where(inventory_collection.manager_ref.first => batch.map(&:first)).each do |record|
                  index = inventory_collection.object_index_with_keys(inventory_collection.manager_ref_to_cols, record)

                  # We need to delete the record from the inventory_objects_index and attributes_index, otherwise it
                  # would be sent for create.
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
            end
          )
        end

        def vms
          super

          custom_reconnect_block = lambda do |inventory_collection, inventory_objects_index, attributes_index|
            relation = inventory_collection.model_class.where(:ems_id => nil)

            return if relation.count <= 0

            inventory_objects_index.each_slice(100) do |batch|
              relation.where(inventory_collection.manager_ref.first => batch.map(&:first)).each do |record|
                index = inventory_collection.object_index_with_keys(inventory_collection.manager_ref_to_cols, record)

                # We need to delete the record from the inventory_objects_index and attributes_index, otherwise it
                # would be sent for create.
                inventory_object = inventory_objects_index.delete(index)
                hash = attributes_index.delete(index)

                record.assign_attributes(hash.except(:id, :type))
                if !inventory_collection.check_changed? || record.changed?
                  record.save!
                  inventory_collection.store_updated_records(record)
                end

                inventory_object.id = record.id
              end
            end
          end

          add_properties(
            :custom_reconnect_block => custom_reconnect_block
          )
        end

        def host_storages
          add_properties(
            :manager_ref                  => %i(host storage),
            :parent_inventory_collections => %i(hosts)
          )
        end

        def host_switches
          add_properties(
            :manager_ref                  => %i(host switch),
            :parent_inventory_collections => %i(hosts)
          )
        end

        def switches
          add_properties(
            :manager_ref => %i(uid_ems)
          )
        end

        def lans
          add_properties(
            :manager_ref => %i(uid_ems),
          )
        end

        def snapshot_parent
          snapshot_parent_save_block = lambda do |_ems, inventory_collection|
            snapshot_collection = inventory_collection.dependency_attributes[:snapshots].try(:first)

            snapshot_collection.each do |snapshot|
              ActiveRecord::Base.transaction do
                child = Snapshot.find(snapshot.id)
                parent = Snapshot.find_by(:uid_ems => snapshot.parent_uid)
                child.update_attribute(:parent_id, parent.try(:id))
              end
            end
          end

          add_properties(
            :custom_save_block => snapshot_parent_save_block
          )
        end
      end
    end
  end
end
