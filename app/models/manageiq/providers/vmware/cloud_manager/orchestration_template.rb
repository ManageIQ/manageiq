class ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplate < OrchestrationTemplate
  def self.eligible_manager_types
    [ManageIQ::Providers::Vmware::CloudManager]
  end
end
