class PersistentVolumeClaim < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :container_project
  has_many :container_volumes # volumes can be reused by a different claim - no dependent destroy
  serialize :capacity, :type => Hash
  serialize :requests, :type => Hash
  serialize :limits, :type => Hash

  virtual_column :storage_capacity, :type => :integer

  def persistent_volume
    container_volumes.find_by_type('PersistentVolume')
  end

  def storage_capacity
    capacity[:storage]
  end
end
