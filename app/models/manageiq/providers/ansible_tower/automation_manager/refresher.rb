module ManageIQ::Providers
  module AnsibleTower
    class AutomationManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin

      def collect_inventory_for_targets(ems, targets)
        ems.with_provider_connection do |connection|
          # FIXME: this should really be somewhere else
          ems.api_version = connection.api.version
          ems.save
        end
        super
      end
    end
  end
end
