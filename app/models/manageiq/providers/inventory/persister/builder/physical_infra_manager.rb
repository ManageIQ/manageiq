module ManageIQ::Providers
  class Inventory::Persister
    class Builder
      class PhysicalInfraManager < ::ManageIQ::Providers::Inventory::Persister::Builder
        def physical_servers
          add_common_default_values
        end

        def physical_racks
          add_common_default_values
        end

        def physical_chassis
          add_common_default_values
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

        # Asset details
        def physical_server_details
          add_asset_detail_properties(:physical_servers)
        end

        def physical_chassis_details
          add_asset_detail_properties(:physical_chassis)
        end

        def physical_storage_details
          add_asset_detail_properties(:physical_storages)
        end

        def physical_switch_details
          add_asset_detail_properties(:physical_switches)
        end

        # Computer systems
        def physical_server_computer_systems
          add_computer_system_properties(:physical_servers)
        end

        def physical_chassis_computer_systems
          add_computer_system_properties(:physical_chassis)
        end

        def physical_storage_computer_systems
          add_computer_system_properties(:physical_storages)
        end

        # Hardwares
        def physical_server_hardwares
          add_hardware_properties(:computer_system, :physical_servers)
        end

        def physical_chassis_hardwares
          add_hardware_properties(:computer_system, :physical_chassis)
        end

        def physical_storage_hardwares
          add_hardware_properties(:computer_system, :physical_storages)
        end

        def physical_switch_hardwares
          add_hardware_properties(:physical_switch, :physical_switches)
        end

        # Guest devices
        def physical_server_network_devices
          add_guest_device_properties
        end

        def physical_server_storage_adapters
          add_guest_device_properties
        end

        # Firmwares
        def physical_server_firmwares
          add_firmware_properties(:physical_servers)
        end

        def physical_switch_firmwares
          add_firmware_properties(:physical_switches)
        end

        private

        def add_asset_detail_properties(parent)
          add_properties(
            :model_class                  => ::AssetDetail,
            :manager_ref                  => %i[resource],
            :parent_inventory_collections => [parent]
          )
        end

        def add_computer_system_properties(parent)
          add_properties(
            :model_class                  => ::ComputerSystem,
            :manager_ref                  => %i[managed_entity],
            :parent_inventory_collections => [parent]
          )
        end

        def add_hardware_properties(manager_ref, parent)
          add_properties(
            :model_class                  => ::Hardware,
            :manager_ref                  => [manager_ref],
            :parent_inventory_collections => [parent]
          )
        end

        def add_guest_device_properties
          add_properties(
            :model_class                  => ::GuestDevice,
            :manager_ref                  => %i[device_type uid_ems],
            :parent_inventory_collections => %i[physical_servers]
          )
        end

        def add_firmware_properties(parent)
          add_properties(
            :model_class                  => ::Firmware,
            :manager_ref                  => %i[name resource],
            :parent_inventory_collections => [parent]
          )
        end
      end
    end
  end
end
