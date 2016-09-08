#
# TODO: (hsong) 
#
module ManageIQ::Providers::StorageManager
  class SwiftStorageManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def parse_legacy_inventory(ems)
      ManageIQ::Providers::StorageManager::SwiftStorageManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
    end

    def save_inventory(ems, target, hashes)
      super
      EmsRefresh.queue_refresh(ems.swift_storage_manager)
    end

  end
end
