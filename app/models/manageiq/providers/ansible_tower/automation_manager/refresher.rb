module ManageIQ::Providers
  module AnsibleTower
    class AutomationManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin

      def parse_legacy_inventory(automation_manager)
        automation_manager.with_provider_connection do |connection|
          # TODO clean up with @ems_data
          automation_manager.api_version = connection.api.version
          automation_manager.save
        end

        ManageIQ::Providers::AnsibleTower::AutomationManager::RefreshParser.automation_manager_inv_to_hashes(automation_manager, refresher_options)
      end
    end
  end
end
