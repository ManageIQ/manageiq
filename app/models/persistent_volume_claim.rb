class PersistentVolumeClaim < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :container_project
  has_many :container_volumes
  serialize :capacity, Hash
  serialize :requests, Hash
  serialize :limits, Hash

  virtual_column :storage_capacity, :type => :integer

  def persistent_volume
    container_volumes.find_by_type('PersistentVolume')
  end

  def storage_capacity
    capacity[:storage]
  end
end
