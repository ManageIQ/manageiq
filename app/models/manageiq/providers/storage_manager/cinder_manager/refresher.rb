#
module ManageIQ::Providers
  class StorageManager::CinderManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def parse_legacy_inventory(ems)
      ManageIQ::Providers::StorageManager::CinderManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
    end

    def post_process_refresh_classes
      []
    end
  end
end
