module OrchestrationStackReconfigureTask::StateMachine
  extend ActiveSupport::Concern

  def run_reconfigure
    _log.info("Reconfiguring stack:<#{stack.name}> in provider:<#{stack.ext_management_system&.name}>")
    stack.raw_reconfigure_stack(:dialog => options[:dialog])
    signal :poll_reconfigure_complete
  rescue => err
    _log.error("Failed to reconfigure stack:<#{stack.name}>, error: #{err}")
    signal :run_reconfigure_failed
  end

  def poll_reconfigure_complete
    status, reason = stack.normalized_live_status

    case status
    when "running"
      stack.queue_refresh
      requeue_phase
    when "create_complete"
      update_and_notify_parent(:state => "finished", :status => "Ok",
                               :message => "Stack reconfigure complete")
    else
      update_and_notify_parent(:state => "finished", :status => "Error",
                               :message => "Stack reconfigure failed: #{reason}")
    end
  end

  def run_reconfigure_failed
    update_and_notify_parent(:state => "finished", :status => "Error",
                             :message => "Stack reconfigure failed to start")
  end
end
