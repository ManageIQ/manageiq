class StorageProfileStorage < ApplicationRecord
  belongs_to :storage_profile
  belongs_to :storage
end
