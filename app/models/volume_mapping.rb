class VolumeMapping < ApplicationRecord
  belongs_to :cloud_volume
  belongs_to :host_initiator

  has_one :storage_resource, :through => :cloud_volume
  has_one :physical_storage, :through => :storage_resource

  belongs_to :ext_management_system, :foreign_key => :ems_id
end
