class PhysicalServer < ApplicationRecord
  acts_as_miq_taggable

  include NewWithTypeStiMixin
  include MiqPolicyMixin
  include TenantIdentityMixin
  include SupportsFeatureMixin
  include EventMixin
  include ProviderObjectMixin
  include ComplianceMixin
  include EmsRefreshMixin
  include CustomActionsMixin

  include Operations

  VENDOR_TYPES = {
    # DB        Displayed
    "lenovo"  => "Lenovo",
    "unknown" => "Unknown",
    nil       => "Unknown",
  }.freeze

  validates :vendor, :inclusion =>{:in => VENDOR_TYPES}
  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_servers,
    :class_name => "ManageIQ::Providers::PhysicalInfraManager"
  belongs_to :physical_rack, :inverse_of => :physical_servers
  belongs_to :physical_chassis, :inverse_of => :physical_servers

  has_one :computer_system, :as => :managed_entity, :dependent => :destroy
  has_one :hardware, :through => :computer_system
  has_one :host, :inverse_of => :physical_server
  has_one :asset_detail, :as => :resource, :dependent => :destroy
  has_many :guest_devices, :through => :hardware
  has_many :miq_alert_statuses, :as => :resource, :dependent => :destroy, :inverse_of => :resource

  scope :with_hosts, -> { where("physical_servers.id in (select hosts.physical_server_id from hosts)") }

  virtual_column :v_availability, :type => :string, :uses => :host
  virtual_column :v_host_os, :type => :string, :uses => :host
  virtual_delegate :emstype, :to => "ext_management_system", :allow_nil => true

  delegate :queue_name_for_ems_operations, :to => :ext_management_system, :allow_nil => true

  has_many :physical_switches, :through => :computer_system, :source => :connected_physical_switches

  has_one :assigned_server_profile, :foreign_key => :assigned_server_id, :dependent => :destroy, :inverse_of => :assigned_server, :class_name => "::PhysicalServerProfile"
  has_one :associated_server_profile, :foreign_key => :associated_server_id, :dependent => :destroy, :inverse_of => :associated_server, :class_name => "::PhysicalServerProfile"

  def name_with_details
    details % {
      :name => name,
    }
  end

  def label_for_vendor
    VENDOR_TYPES[vendor]
  end

  def is_refreshable?
    refreshable_status[:show]
  end

  def is_refreshable_now?
    refreshable_status[:enabled]
  end

  def is_refreshable_now_error_message
    refreshable_status[:message]
  end

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def event_where_clause(assoc = :ems_events)
    ["#{events_table_name(assoc)}.physical_server_id = ?", id]
  end

  def v_availability
    host.try(:physical_server_id).nil? ? N_("Available") : N_("In use")
  end

  def v_host_os
    host.try(:vmm_product).nil? ? N_("") : host.vmm_product
  end

  def compatible_firmware_binaries
    FirmwareTarget.find_compatible_with(asset_detail.attributes)&.firmware_binaries || []
  end

  def firmware_compatible?(firmware_binary)
    filter = asset_detail.attributes.slice(*FirmwareTarget::MATCH_ATTRIBUTES).transform_values(&:downcase)
    firmware_binary.firmware_targets.find_by(filter).present?
  end
end
