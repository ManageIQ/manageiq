#
# TODO: (hsong) 
#
module ManageIQ::Providers
  class StorageManager::CinderStorageManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def parse_legacy_inventory(ems)
      ManageIQ::Providers::StorageManager::CinderStorageManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
    end

    def save_inventory(ems, target, hashes)
      super
      EmsRefresh.queue_refresh(ems.cinder_storage_manager)
    end

  end
end
