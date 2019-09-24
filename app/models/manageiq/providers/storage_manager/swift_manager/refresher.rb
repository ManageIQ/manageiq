module ManageIQ::Providers
  class StorageManager::SwiftManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    def parse_legacy_inventory(ems)
      ManageIQ::Providers::StorageManager::SwiftManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
    end

    def post_process_refresh_classes
      []
    end
  end
end
