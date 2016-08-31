class ManageIQ::Providers::Vmware::CloudManager::OrchestrationStack::Status < ::OrchestrationStack::Status
  def succeeded?
    status.casecmp("on") == 0
  end

  def failed?
    status.casecmp("failed_creation") == 0
  end
end
