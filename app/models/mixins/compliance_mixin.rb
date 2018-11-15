module ComplianceMixin
  extend ActiveSupport::Concern

  included do
    has_many :compliances, :as => :resource, :dependent => :destroy
    has_one  :last_compliance,
             -> { order('"compliances"."timestamp" DESC') },
             :as         => :resource,
             :inverse_of => :resource,
             :class_name => "Compliance"

    virtual_delegate :last_compliance_status,
                     :to        => "last_compliance.compliant",
                     :allow_nil => true
    virtual_delegate :timestamp,
                     :to        => :last_compliance,
                     :allow_nil => true,
                     :prefix    => true
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
end
