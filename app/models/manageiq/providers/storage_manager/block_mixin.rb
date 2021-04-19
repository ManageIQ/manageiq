module ManageIQ::Providers::StorageManager::BlockMixin
  extend ActiveSupport::Concern

  included do
    supports :block_storage
    supports :object_storage
  end
end
