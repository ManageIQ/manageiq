class PhysicalServer < ApplicationRecord
  include NewWithTypeStiMixin
  include MiqPolicyMixin
  include TenantIdentityMixin
  include SupportsFeatureMixin
  include EventMixin

  include_concern 'Operations'

  acts_as_miq_taggable

  VENDOR_TYPES = {
    # DB        Displayed
    "lenovo"  => "Lenovo",
    "unknown" => "Unknown",
    nil       => "Unknown",
  }.freeze

  validates :vendor, :inclusion =>{:in => VENDOR_TYPES}
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::PhysicalInfraManager"

  has_one :computer_system, :as => :managed_entity, :dependent => :destroy
  has_one :hardware, :through => :computer_system
  has_one :host, :inverse_of => :physical_server
  has_one :asset_detail, :as => :resource, :dependent => :destroy

  scope :with_hosts, -> { where("physical_servers.id in (select hosts.physical_server_id from hosts)") }

  def name_with_details
    details % {
      :name => name,
    }
  end

  def has_compliance_policies?
    _, plist = MiqPolicy.get_policies_for_target(self, "compliance", "physicalserver_compliance_check")
    !plist.blank?
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

  def is_available?(_address)
    # TODO: (walteraa) remove bypass
    true
  end

  def smart?
    # TODO: (walteraa) remove bypass
    true
  end

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def event_where_clause(assoc = :ems_events)
    ["#{events_table_name(assoc)}.physical_server_id = ?", id]
  end

  def self.refresh_ems(physical_server_ids)
    physical_server_ids = [physical_server_ids] unless physical_server_ids.kind_of?(Array)
    physical_server_ids = physical_server_ids.collect { |id| [PhysicalServer, id] }
    EmsRefresh.queue_refresh(physical_server_ids)
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
    EmsRefresh.queue_refresh(self)
  end
end
