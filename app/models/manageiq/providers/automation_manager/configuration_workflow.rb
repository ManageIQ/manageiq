class ManageIQ::Providers::AutomationManager::ConfigurationWorkflow < ::ConfigurationWorkflow
  belongs_to :manager, :class_name => "ManageIQ::Providers::AutomationManager", :inverse_of => :configuration_workflows
end
