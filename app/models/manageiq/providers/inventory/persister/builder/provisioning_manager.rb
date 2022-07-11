module ManageIQ::Providers
  class Inventory::Persister
    class Builder
      class ProvisioningManager < ::ManageIQ::Providers::Inventory::Persister::Builder
        def customization_script_media
          skip_sti
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:ext_management_system => manager)
        end

        def customization_script_ptables
          skip_sti
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:ext_management_system => manager)
        end

        def operating_system_flavors
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:provisioning_manager => manager)
        end

        def configuration_locations
          skip_sti
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:provisioning_manager => manager)
        end

        def configuration_organizations
          skip_sti
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:provisioning_manager => manager)
        end

        def configuration_tags
          skip_sti
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:manager => manager)
        end

        def configuration_architectures
          skip_sti
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:manager => manager)
        end

        def configuration_compute_profiles
          skip_sti
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:manager => manager)
        end

        def configuration_domains
          skip_sti
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:manager => manager)
        end

        def configuration_environments
          skip_sti
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:manager => manager)
        end

        def configuration_realms
          skip_sti
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:manager => manager)
        end
      end
    end
  end
end
