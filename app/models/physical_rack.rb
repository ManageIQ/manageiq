class PhysicalRack < ApplicationRecord
  include SupportsFeatureMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_racks,
    :class_name => "ManageIQ::Providers::PhysicalInfraManager"
  has_many :physical_chassis, :dependent => :nullify, :inverse_of => :physical_rack
  has_many :physical_servers, :dependent => :nullify, :inverse_of => :physical_rack
  has_many :physical_storages, :dependent => :nullify, :inverse_of => :physical_rack

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
