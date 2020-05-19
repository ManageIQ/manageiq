module ComplianceMixin
  extend ActiveSupport::Concern

  included do
    has_many :compliances, :as => :resource, :dependent => :destroy
    has_one  :last_compliance,
             -> { order(:timestamp => :desc) },
             :as         => :resource,
             :inverse_of => :resource,
             :class_name => "Compliance"
    virtual_has_many :last_compliance_conditions, :uses => { :last_compliance => :condition }

    virtual_delegate :last_compliance_status,
                     :to        => "last_compliance.compliant",
                     :type      => :boolean,
                     :allow_nil => true
    virtual_delegate :timestamp,
                     :to        => :last_compliance,
                     :allow_nil => true,
                     :type      => :datetime,
                     :prefix    => true

    virtual_column :last_compliance_condition_expressions, :type => :string_set, :uses => { :last_compliance => :condition }
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
    _, plist = MiqPolicy.get_policies_for_target(self, "compliance", "#{target_class}_compliance_check")
    plist
  end

  def last_compliance_conditions
    return [] unless last_compliance

    last_compliance.compliance_details.map(&:condition)
  end

  def last_compliance_condition_expressions
    last_compliance_conditions.map {|c| c.expression.to_human}
  end
end
