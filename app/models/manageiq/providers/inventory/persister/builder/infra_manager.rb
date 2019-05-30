module ManageIQ::Providers
  class Inventory::Persister
    class Builder
      class InfraManager < ::ManageIQ::Providers::Inventory::Persister::Builder
        def networks
          add_properties(
            :manager_ref                  => %i(hardware ipaddress ipv6address),
            :parent_inventory_collections => %i(vms miq_templates),
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
            :manager_ref                  => %i(hardware uid_ems),
            :parent_inventory_collections => %i(vms miq_templates),
          )
        end

        def host_guest_devices
          add_properties(
            :model_class                  => ::GuestDevice,
            :manager_ref                  => %i(hardware uid_ems),
            :parent_inventory_collections => %i(hosts),
          )
        end

        def host_hardwares
          add_properties(
            :model_class                  => ::Hardware,
            :manager_ref                  => %i(host),
            :parent_inventory_collections => %i(hosts)
          )
        end

        def host_system_services
          add_properties(
            :model_class                  => ::SystemService,
            :manager_ref                  => %i(host name),
            :parent_inventory_collections => %i(hosts)
          )
        end

        def snapshots
          add_properties(
            :manager_ref                  => %i(vm_or_template uid),
            :parent_inventory_collections => %i(vms miq_templates),
          )
        end

        def host_operating_systems
          add_properties(
            :model_class                  => ::OperatingSystem,
            :manager_ref                  => %i(host),
            :parent_inventory_collections => %i(hosts),
          )
        end

        def ems_custom_attributes
          add_properties(
            :model_class                  => ::CustomAttribute,
            :manager_ref                  => %i(name),
            :parent_inventory_collections => %i(vms miq_templates),
          )
        end

        def vm_and_template_ems_custom_fields
          skip_auto_inventory_attributes

          add_properties(
            :model_class                  => ::CustomAttribute,
            :manager_ref                  => %i(name),
            :parent_inventory_collections => %i(vms)
          )

          add_inventory_attributes(%i(section name value source resource))
        end

        def ems_folders
          add_properties(
            :manager_ref          => %i[uid_ems],
            :attributes_blacklist => %i[parent],
          )
          add_common_default_values
        end

        def datacenters
          add_properties(:attributes_blacklist => %i[parent])
          add_common_default_values
        end

        def resource_pools
          add_properties(
            :manager_ref          => %i[uid_ems],
            :attributes_blacklist => %i[parent],
          )
          add_common_default_values
        end

        def ems_clusters
          add_properties(:attributes_blacklist => %i[datacenter_id parent])
          add_inventory_attributes(%i[datacenter_id])
          add_common_default_values
        end

        def storages
          add_properties(
            :manager_ref          => %i[location],
            :complete             => false,
            :arel                 => Storage,
            :attributes_blacklist => %i[parent],
          )
        end

        def hosts
          add_properties(:attributes_blacklist => %i[parent])
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
          vm_template_infra_shared_properties
        end

        def miq_templates
          super
          vm_template_infra_shared_properties
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

        def host_virtual_switches
          add_properties(
            :manager_ref                  => %i(host uid_ems),
            :model_class                  => Switch,
            :parent_inventory_collections => %i(hosts)
          )
        end

        def distributed_virtual_switches
          add_properties(
            :manager_ref          => %i[uid_ems],
            :attributes_blacklist => %i[parent],
            :secondary_refs       => {:by_switch_uuid => %i[switch_uuid]}
          )
          add_common_default_values
        end

        def lans
          add_properties(
            :manager_ref                  => %i(switch uid_ems),
            :parent_inventory_collections => %i(hosts),
          )
        end

        def subnets
          add_properties(
            :manager_ref                  => %i(lan ems_ref),
            :parent_inventory_collections => %i(hosts),
          )
        end

        def customization_specs
          add_properties(:manager_ref => %i(name))

          add_common_default_values
        end

        def miq_scsi_luns
          add_properties(
            :manager_ref                  => %i(miq_scsi_target uid_ems),
            :parent_inventory_collections => %i(hosts)
          )
        end

        def miq_scsi_targets
          add_properties(
            :manager_ref                  => %i(guest_device uid_ems),
            :parent_inventory_collections => %i(hosts)
          )
        end

        def storage_profiles
          add_common_default_values
        end

        def ems_extensions
          add_common_default_values
        end

        def ems_licenses
          add_common_default_values
        end

        def root_folder_relationship
          skip_auto_inventory_attributes
          skip_model_class

          add_properties(
            :custom_save_block => root_folder_relationship_save_block
          )

          add_dependency_attributes(
            :ems_folders => ->(persister) { [persister.collections[:ems_folders]] },
          )
        end

        def parent_blue_folders
          skip_auto_inventory_attributes
          skip_model_class

          add_properties(
            :custom_save_block => relationship_save_block(:relationship_key => :parent)
          )

          dependency_collections = %i[ems_clusters ems_folders datacenters hosts resource_pools storages]
          dependency_attributes = dependency_collections.each_with_object({}) do |collection, hash|
            hash[collection] = ->(persister) { [persister.collections[collection]].compact }
          end
          add_dependency_attributes(dependency_attributes)
        end

        def vm_parent_blue_folders
          skip_auto_inventory_attributes
          skip_model_class

          add_properties(
            :custom_save_block => relationship_save_block(:relationship_key => :parent, :parent_type => "EmsFolder")
          )

          add_dependency_attributes(
            :vms => ->(persister) { persister.collections.values_at(:vms, :miq_templates, :vms_and_templates).compact }
          )
        end

        def vm_resource_pools
          skip_auto_inventory_attributes
          skip_model_class

          add_properties(
            :custom_save_block => relationship_save_block(
              :relationship_key => :resource_pool, :parent_type => "ResourcePool"
            )
          )

          add_dependency_attributes(
            :vms => ->(persister) { persister.collections.values_at(:vms, :miq_templates, :vms_and_templates).compact }
          )
        end

        private

        def root_folder_relationship_save_block
          lambda do |ems, inventory_collection|
            folder_inv_collection = inventory_collection.dependency_attributes[:ems_folders]&.first
            return if folder_inv_collection.nil?

            # All folders must have a parent except for the root folder
            root_folder_obj = folder_inv_collection.data.detect { |obj| obj.data[:parent].nil? }
            return if root_folder_obj.nil?

            root_folder = folder_inv_collection.model_class.find(root_folder_obj.id)
            root_folder.with_relationship_type(:ems_metadata) { root_folder.parent = ems }
          end
        end

        def vm_template_infra_shared_properties
          add_inventory_attributes(%i[resource_pool])
          add_properties(:custom_reconnect_block => vm_template_infra_reconnect_block)
        end

        def vm_template_infra_reconnect_block
          lambda do |inventory_collection, inventory_objects_index, attributes_index|
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
        end
      end
    end
  end
end
