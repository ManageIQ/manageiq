class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job::Status < ::OrchestrationStack::Status
  attr_accessor :task_status

  # This is a bit confusing, but because the OrchestrationStack::Status doesn't
  # have a concept of both state and status as MiqTask does, inverting is the
  # "DRYest" way to match up with `normalized_status` found in
  # OrchestrationStack::Status.
  def initialize(miq_task, reason)
    super(miq_task.state, reason)
    self.task_status = miq_task.status
  end

  def completed?
    status == MiqTask::STATE_FINISHED
  end

  def succeeded?
    completed? && task_status == MiqTask::STATUS_OK
  end

  def failed?
    completed? && task_status != MiqTask::STATUS_OK
  end
end
