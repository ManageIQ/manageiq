class PhysicalChassis < ApplicationRecord
  include SupportsFeatureMixin
  include EventMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_chassis,
    :class_name => "ManageIQ::Providers::PhysicalInfraManager"
  belongs_to :physical_rack, :foreign_key => :physical_rack_id, :inverse_of => :physical_chassis
  belongs_to :parent_physical_chassis,
             :class_name => "PhysicalChassis",
             :inverse_of => :child_physical_chassis

  has_many :event_streams, :inverse_of => :physical_chassis, :dependent => :nullify
  has_many :physical_servers, :dependent => :destroy, :inverse_of => :physical_chassis
  has_many :physical_storages, :dependent => :destroy, :inverse_of => :physical_chassis
  has_many :child_physical_chassis,
           :class_name  => "PhysicalChassis",
           :dependent   => :nullify,
           :foreign_key => :parent_physical_chassis_id,
           :inverse_of  => :parent_physical_chassis

  has_one :computer_system, :as => :managed_entity, :dependent => :destroy, :inverse_of => false
  has_one :hardware, :through => :computer_system
  has_one :asset_detail, :as => :resource, :dependent => :destroy, :inverse_of => false
  has_many :guest_devices, :through => :hardware

  supports :refresh_ems

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def event_where_clause(assoc = :ems_events)
    ["#{events_table_name(assoc)}.physical_chassis_id = ?", id]
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
