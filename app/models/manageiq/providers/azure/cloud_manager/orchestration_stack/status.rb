class ManageIQ::Providers::Azure::CloudManager::OrchestrationStack::Status < ::OrchestrationStack::Status
  def succeeded?
    status.downcase == "succeeded"
  end

  def failed?
    status.downcase == "failed"
  end

  def canceled?
    status.downcase == "canceled"
  end

  def deleted?
    status.downcase == "deleted"
  end
end
