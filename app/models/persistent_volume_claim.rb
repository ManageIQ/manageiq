class PersistentVolumeClaim < ActiveRecord::Base
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :persistent_volume
  has_many :container_volumes
  serialize :capacity, Hash
end
