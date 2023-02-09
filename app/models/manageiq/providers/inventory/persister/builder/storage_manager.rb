module ManageIQ::Providers
  class Inventory::Persister
    class Builder
      class StorageManager < ::ManageIQ::Providers::Inventory::Persister::Builder
        def cloud_volumes
          add_common_default_values
        end

        def cloud_volume_snapshots
          add_common_default_values
        end

        def cloud_volume_types
          add_common_default_values
        end

        def cloud_volume_backups
          add_common_default_values
        end

        def cloud_object_store_objects
          add_common_default_values
        end

        def cloud_object_store_containers
          add_common_default_values
        end

        def host_initiators
          add_common_default_values
        end

        def host_initiator_groups
          add_common_default_values
        end

        def physical_storages
          add_common_default_values
        end

        def physical_storage_families
          add_common_default_values
        end

        def san_addresses
          skip_sti
          add_common_default_values
        end

        def storage_resources
          add_common_default_values
        end

        def storage_services
          add_common_default_values
        end

        def storage_service_resource_attachments
          add_common_default_values
        end

        def volume_mappings
          add_common_default_values
        end

        def wwpn_candidates
          add_common_default_values
        end
      end
    end
  end
end
