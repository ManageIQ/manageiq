module ManageIQ::Providers::Azure
  class CloudManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def parse_legacy_inventory(ems)
      ManageIQ::Providers::Azure::CloudManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
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
