class PhysicalRack < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_racks

  has_many :physical_chassis, :dependent => :nullify, :inverse_of => :physical_rack
  has_many :physical_servers, :dependent => :nullify, :inverse_of => :physical_rack
end
