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

        def cloud_object_store_objects
          add_common_default_values
        end

        def cloud_object_store_containers
          add_common_default_values
        end

        def host_initiators
          add_properties(:parent_inventory_collections => [:physical_storages])
          add_common_default_values
        end

        def volume_mappings
          add_common_default_values
        end
      end
    end
  end
end
