module ComplianceMixin
  extend ActiveSupport::Concern

  included do
    has_many :compliances, :as => :resource, :dependent => :destroy
    has_one  :last_compliance,
             -> { order(:timestamp => :desc) },
             :as         => :resource,
             :inverse_of => :resource,
             :class_name => "Compliance"

    supports(:check_compliance) { "No compliance policies assigned" unless has_compliance_policies? }

    virtual_attribute :last_compliance_status, :boolean, :through => :last_compliance, :source => :compliant
    virtual_attribute :last_compliance_timestamp, :datetime, :through => :last_compliance, :source => :timestamp
  end

  def check_compliance
    Compliance.check_compliance(self)
  end

  def check_compliance_queue
    Compliance.check_compliance_queue(self)
  end

  def scan_and_check_compliance_queue
    Compliance.scan_and_check_compliance_queue(self)
  end

  def compliance_policies
    target_class = self.class.base_model.name.downcase
    target_class = "vm" if target_class.include?("template")
    _, plist = MiqPolicy.get_policies_for_target(self, "compliance", "#{target_class}_compliance_check")
    plist
  end

  def has_compliance_policies?
    compliance_policies.present?
  end
end
