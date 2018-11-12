module ManageIQ::Providers
  class Inventory::Persister
    class Builder
      class PhysicalInfraManager < ::ManageIQ::Providers::Inventory::Persister::Builder
        def physical_servers
          add_common_default_values
        end

        def physical_server_details
          add_properties(
            :model_class                  => ::AssetDetail,
            :manager_ref                  => %i(resource),
            :parent_inventory_collections => %i(physical_servers)
          )
        end

        def computer_systems
          add_properties(
            :manager_ref                  => %i(managed_entity),
            :parent_inventory_collections => %i(physical_servers)
          )
        end

        def hardwares
          add_properties(
            :manager_ref                  => %i(computer_system),
            :parent_inventory_collections => %i(physical_servers)
          )
        end

        def physical_racks
          add_common_default_values
        end

        def physical_chassis
          add_common_default_values
        end

        def physical_chassis_details
          add_properties(
            :model_class                  => ::AssetDetail,
            :manager_ref                  => %i(resource),
            :parent_inventory_collections => %i(physical_chassis)
          )
        end

        def physical_storages
          add_common_default_values
        end

        def physical_switches
          add_properties(:manager_ref => %i(uid_ems))
          add_common_default_values
        end

        def customization_scripts
          add_properties(:manager_ref => %i(manager_ref))
          add_default_values(:manager_id => ->(persister) { persister.manager.id })
        end
      end
    end
  end
end
