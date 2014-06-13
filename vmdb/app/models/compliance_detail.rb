class ComplianceDetail < ActiveRecord::Base
  belongs_to  :compliance
  belongs_to  :condition
  belongs_to  :miq_policy

  include ReportableMixin

  virtual_column :resource_name, :type => :string, :uses => {:compliance => :resource}

  def resource_name
    self.compliance.resource.name
  end
end
