module ManageIQ::Providers::StorageManager::BlockMixin
  extend ActiveSupport::Concern

  included do
    supports :block_storage
  end
end
