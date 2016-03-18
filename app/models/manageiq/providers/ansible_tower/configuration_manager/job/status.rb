class ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job::Status < ::OrchestrationStack::Status
  def succeeded?
    status.casecmp("successful").zero?
  end

  def failed?
    status.casecmp("failed").zero?
  end

  def canceled?
    status.casecmp("canceled").zero?
  end
end
