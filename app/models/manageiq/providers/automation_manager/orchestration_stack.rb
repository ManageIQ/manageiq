class ManageIQ::Providers::AutomationManager::OrchestrationStack < ::OrchestrationStack
  include CiFeatureMixin

  def retireable?
    false
  end
end
