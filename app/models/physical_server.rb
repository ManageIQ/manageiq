class PhysicalServer < ApplicationRecord
  include NewWithTypeStiMixin
  include MiqPolicyMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::PhysicalInfraManager"

  has_one :host, :inverse_of => :physical_server

  VENDOR_TYPES = {
     # DB            Displayed
    "lenovo"          => "lenovo",
    "unknown"         => "Unknown",
    nil               => "Unknown",
  }

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
    VENDOR_TYPES[self.vendor]
  end
end
