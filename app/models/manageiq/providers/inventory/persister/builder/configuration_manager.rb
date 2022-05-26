module ManageIQ::Providers
  class Inventory::Persister
    class Builder
      class ConfigurationManager < ::ManageIQ::Providers::Inventory::Persister::Builder
        def configuration_profiles
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:manager_id => parent_id)
        end

        def configured_systems
          add_properties(:manager_ref => %i[manager_ref])
          add_default_values(:manager_id => parent_id)
        end
      end
    end
  end
end
