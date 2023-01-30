class WorkflowInstance < ApplicationRecord
  include NewWithTypeStiMixin
  include TenancyMixin

  belongs_to :ext_management_system, :inverse_of => :workflow_instances, :class_name => "ManageIQ::Providers::AutomationManager", :foreign_key => :ems_id
  belongs_to :tenant
  belongs_to :miq_task
  belongs_to :workflow

  validates :status, :inclusion => {:in => %w[pending running canceling success warning error canceled]}
end
