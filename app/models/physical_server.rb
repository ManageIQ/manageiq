class PhysicalServer < ApplicationRecord
  include NewWithTypeStiMixin
  include MiqPolicyMixin
  include_concern 'Operations'

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::PhysicalInfraManager"

  has_one :computer_system, :as => :managed_entity, :dependent => :destroy
  has_one :hardware, :through => :computer_system

  has_one :host, :inverse_of => :physical_server

  VENDOR_TYPES = {
    # DB        Displayed
    "lenovo"  => "lenovo",
    "unknown" => "Unknown",
    nil       => "Unknown",
  }.freeze

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
    VENDOR_TYPES[vendor.downcase]
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
end
