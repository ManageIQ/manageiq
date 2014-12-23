module ComplianceMixin
  extend ActiveSupport::Concern

  included do
    has_many :compliances, :as => :resource, :dependent => :destroy

    virtual_has_one :last_compliance, :class_name => "Compliance"

    virtual_column  :last_compliance_status,    :type => :boolean,  :uses => :last_compliance
    virtual_column  :last_compliance_timestamp, :type => :datetime, :uses => :last_compliance
  end

  def last_compliance
    return @last_compliance unless @last_compliance.nil?
    @last_compliance = if association_cache.include?(:compliances)
      self.compliances.sort_by { |c| c.timestamp }.last
    else
      self.compliances.order("timestamp DESC").first
    end
  end

  def last_compliance_status
    lc = self.last_compliance
    lc.nil? ? nil : lc.compliant
  end

  def last_compliance_timestamp
    lc = self.last_compliance
    lc.nil? ? nil : lc.timestamp
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
