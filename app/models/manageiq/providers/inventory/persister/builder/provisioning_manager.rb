module ManageIQ::Providers
  class Inventory::Persister
    class Builder
      class ProvisioningManager < ::ManageIQ::Providers::Inventory::Persister::Builder
        def customization_scripts
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:manager_id => ->(persister) { persister.manager.id })
        end

        def operating_system_flavors
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:provisioning_manager_id => ->(persister) { persister.manager.id })
        end

        def configuration_locations
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:provisioning_manager_id => ->(persister) { persister.manager.id })
        end

        def configuration_organizations
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:provisioning_manager_id => ->(persister) { persister.manager.id })
        end

        def configuration_tags
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:manager_id => ->(persister) { persister.manager.id })
        end
      end
    end
  end
end
