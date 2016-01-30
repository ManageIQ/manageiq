module ManageIQ::Providers
  module AnsibleTower
    class ConfigurationManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin

      def parse_inventory(configuration_manager, _targets)
        configuration_manager.with_provider_connection do |connection|
          configuration_manager.api_version = connection.version
          configuration_manager.save
        end

        ManageIQ::Providers::AnsibleTower::ConfigurationManager::RefreshParser.configuration_manager_inv_to_hashes(configuration_manager, refresher_options)
      end
    end
  end
end
