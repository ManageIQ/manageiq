class PhysicalStorage < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_storages,
   :class_name => "ManageIQ::Providers::PhysicalInfraManager"

  belongs_to :physical_rack, :foreign_key => :physical_rack_id, :inverse_of => :physical_storages

  has_one :computer_system, :as => :managed_entity, :dependent => :destroy, :inverse_of => false
  has_one :hardware, :through => :computer_system
  has_one :asset_detail, :as => :resource, :dependent => :destroy, :inverse_of => false
  has_many :guest_devices, :through => :hardware
end
