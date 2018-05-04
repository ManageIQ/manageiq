module ManagerRefresh
  class InventoryCollection
    class Builder
      # TODO: (mslemr) Remove /manager_refresh/inventory/[core, automation_manager, cloud_manager, ?middleware_manager?].rb
      # TODO: (mslemr) think about lib/generators/provider/templates/app/models/manageiq/providers/%provider_name%/inventory/persister/cloud_manager.rb
      class AutomationManager < ::ManagerRefresh::InventoryCollection::Builder
        def configuration_scripts
          default_manager_ref
          default_builder_params
        end

        def configuration_script_payloads
          add_properties(
            :manager_ref => %i(configuration_script_source manager_ref)
          )
          default_builder_params
        end

        def configuration_script_sources
          default_manager_ref
          default_builder_params
        end

        def configured_systems
          default_manager_ref
          default_builder_params
        end

        def credentials
          default_manager_ref
          add_builder_params(
            :resource => ->(persister) { persister.manager }
          )
        end

        def inventory_root_groups
          default_builder_params
        end

        def vms
          add_properties(:manager_ref => %i(uid_ems))
        end

        protected

        def default_manager_ref
          add_properties(:manager_ref => %i(manager_ref))
        end

        def default_builder_params
          add_builder_params(
            :manager => ->(persister) { persister.manager }
          )
        end
      end
    end
  end
end
