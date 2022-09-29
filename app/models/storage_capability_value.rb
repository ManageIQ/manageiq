class StorageCapabilityValue < ApplicationRecord

  belongs_to :storage_capability, :foreign_key => :capability_id, :dependent => :destroy
  belongs_to :ext_management_system, :foreign_key => :ems_id

  has_many :storage_service_capabilities, :foreign_key => :capability_id
  has_many :storage_services, :through => :storage_service_capabilities
end
