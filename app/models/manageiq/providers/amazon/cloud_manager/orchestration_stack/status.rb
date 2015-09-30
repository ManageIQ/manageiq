class ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack::Status < ::OrchestrationStack::Status
  def succeeded?
    status.downcase == "create_complete"
  end

  def failed?
    status.downcase =~ /failed$/
  end

  def rolled_back?
    status.downcase == "rollback_complete"
  end

  def deleted?
    status.downcase == "delete_complete"
  end
end
