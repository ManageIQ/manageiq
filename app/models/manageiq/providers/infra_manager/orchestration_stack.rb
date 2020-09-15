class ManageIQ::Providers::InfraManager::OrchestrationStack < ::OrchestrationStack
  include CiFeatureMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::InfraManager", :inverse_of => false
  belongs_to :orchestration_template
end
