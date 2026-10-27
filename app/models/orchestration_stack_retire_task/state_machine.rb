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

  def parent_service
    return @parent_service if defined?(@parent_service)

    @parent_service = Service.find_by(:id => options[:parent_service_id])
  end

  def failed_retirement
    _status, reason = stack.normalized_live_status
    stack.update(:retirement_state => RetirementMixin::RETIREMENT_ERROR)
    parent_service&.update(:retirement_state => RetirementMixin::RETIREMENT_ERROR)
    fail!("#{self.class.model_being_retired} failed to retire, caused by #{reason}")
  end
end
