class PersistentVolumeClaim < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :container_project
  has_many :container_volumes
  serialize :capacity, Hash

  def persistent_volume
    container_volumes.find_by_type('PersistentVolume')
  end
end
