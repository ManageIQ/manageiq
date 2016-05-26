class ComplianceDetail < ApplicationRecord
  belongs_to  :compliance
  belongs_to  :condition
  belongs_to  :miq_policy

  virtual_column :resource_name, :type => :string, :uses => {:compliance => :resource}

  def resource_name
    compliance.resource.name
  end
end
