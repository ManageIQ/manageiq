module OrchestrationStackRetireTask::StateMachine
  extend ActiveSupport::Concern

  def remove_from_provider
    if stack.raw_exists?
      _log.info("Removing stack:<#{stack.name}> from provider:<#{stack.ext_management_system&.name}>")
      stack.raw_delete_stack
    end

    signal :check_removed_from_provider
  end

  def check_removed_from_provider
    status, _reason = stack.normalized_live_status

    case status
    when 'not_exist', 'delete_complete'
      signal :finish_retirement
    when /failed$/
      signal :failed_retirement
    else
      stack.queue_refresh
      requeue_phase
    end
  end
end
