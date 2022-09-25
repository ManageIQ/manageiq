class StorageCapabilityValue < ApplicationRecord
  has_many :capability_values, :primary_key => :capability_id
  has_many :storage_services, :primary_key => :service_uuid
end
