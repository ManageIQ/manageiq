class ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplate < OrchestrationTemplate
  def self.eligible_manager_types
    [ManageIQ::Providers::Vmware::CloudManager]
  end

  def self.stack_type
    "VMware vApp"
  end
end
