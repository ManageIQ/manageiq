module OrchestrationStackRetireTask::StateMachine
  extend ActiveSupport::Concern

  def remove_from_provider
    stack.raw_delete_stack if stack.raw_exists?

    signal :check_removed_from_provider
  end

  def check_removed_from_provider
    status, _reason = stack.normalized_live_status
    if status == 'not_exist' || status == 'delete_complete'
      signal :finish_retirement
    else
      stack.queue_refresh
      requeue_phase
    end
  end
end
