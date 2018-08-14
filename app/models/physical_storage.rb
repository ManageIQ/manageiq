class PhysicalStorage < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_storages,
   :class_name => "ManageIQ::Providers::PhysicalInfraManager"
  belongs_to :physical_rack, :foreign_key => :physical_rack_id, :inverse_of => :physical_storages
  belongs_to :physical_chassis, :inverse_of => :physical_storages

  has_one :computer_system, :as => :managed_entity, :dependent => :destroy, :inverse_of => false
  has_one :hardware, :through => :computer_system
  has_one :asset_detail, :as => :resource, :dependent => :destroy, :inverse_of => false
  has_many :guest_devices, :through => :hardware

  has_many :physical_disks, :dependent => :destroy, :inverse_of => :physical_storages

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def refresh_ems
    unless ext_management_system
      raise _("No Provider defined")
    end
    unless ext_management_system.has_credentials?
      raise _("No Provider credentials defined")
    end
    unless ext_management_system.authentication_status_ok?
      raise _("Provider failed last authentication check")
    end

    EmsRefresh.queue_refresh(ext_management_system)
  end
end
