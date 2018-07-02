class ManageIQ::Providers::AutomationManager::ConfigurationWorkflow < ::ConfigurationScript
  belongs_to :manager, :class_name => "ManageIQ::Providers::AutomationManager", :inverse_of => :configuration_workflows
end
