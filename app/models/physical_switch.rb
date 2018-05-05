class PhysicalSwitch < Switch
  has_one :asset_detail, :as => :resource, :dependent => :destroy, :inverse_of => :resource
  has_one :hardware, :dependent => :destroy, :foreign_key => :switch_id, :inverse_of => :physical_switch

  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_switches
end
