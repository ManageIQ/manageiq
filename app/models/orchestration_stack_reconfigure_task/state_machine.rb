module OrchestrationStackReconfigureTask::StateMachine
  extend ActiveSupport::Concern

  def reconfigure_in_provider
    _log.info("Reconfiguring stack:<#{stack.name}> in provider:<#{stack.ext_management_system&.name}>")
    stack.raw_reconfigure_stack(:dialog => options[:dialog])
    signal :poll_reconfigure_complete
  rescue => err
    _log.error("Failed to reconfigure stack:<#{stack.name}>, error: #{err}")
    signal :reconfigure_in_provider_failed
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

  def reconfigure_in_provider_failed
    update_and_notify_parent(:state => "finished", :status => "Error",
                             :message => "Stack reconfigure failed to start")
  end
end
