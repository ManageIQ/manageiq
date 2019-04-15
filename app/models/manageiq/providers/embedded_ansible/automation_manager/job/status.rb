class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job::Status < ::OrchestrationStack::Status
  alias miq_task status

  def succeeded?
    miq_task.state == MiqTask::STATE_FINISHED && miq_task.status == MiqTask::STATUS_OK
  end

  def failed?
    miq_task.state == MiqTask::STATE_FINISHED && miq_task.status != MiqTask::STATUS_OK
  end
end
