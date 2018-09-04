class PhysicalStorage < ApplicationRecord
  include SupportsFeatureMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_storages,
   :class_name => "ManageIQ::Providers::PhysicalInfraManager"
  belongs_to :physical_rack, :foreign_key => :physical_rack_id, :inverse_of => :physical_storages
  belongs_to :physical_chassis, :inverse_of => :physical_storages

  has_one :asset_detail, :as => :resource, :dependent => :destroy, :inverse_of => false

  has_many :canisters, :dependent => :destroy, :inverse_of => false
  has_many :computer_system, :through => :canisters
  has_many :hardware, :through => :computer_system
  has_many :guest_devices, :through => :canisters

  has_many :physical_disks, :dependent => :destroy, :inverse_of => :physical_storage

  supports :refresh_ems

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
