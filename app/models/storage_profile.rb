class StorageProfile < ApplicationRecord
  has_many :storage_profile_storages, :dependent  => :destroy
  has_many :storages,                 :through    => :storage_profile_storages
end
