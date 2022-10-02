class StorageCapabilityValue < ApplicationRecord

  belongs_to :storage_capability, :inverse_of => :storage_capability_values
  belongs_to :ext_management_system, :foreign_key => :ems_id
end
