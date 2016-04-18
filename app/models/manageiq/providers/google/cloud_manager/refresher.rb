module ManageIQ::Providers::Google
  class CloudManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def collect_inventory_for_targets(ems, targets)
      [[ems, nil]]
    end

    def parse_targeted_inventory(ems, target, inventory)
      ManageIQ::Providers::Google::CloudManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
    end

    def save_inventory(ems, _targets, hashes)
      EmsRefresh.save_ems_inventory(ems, hashes)
      EmsRefresh.queue_refresh(ems.network_manager)
    end

    def post_process_refresh_classes
      [::Vm]
    end
  end
end
