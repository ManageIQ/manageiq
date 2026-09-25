class OrchestrationStackReconfigureTask < MiqReconfigureTask
  include StateMachine

  AUTOMATE_DRIVES = false

  default_value_for :request_type, "orchestration_stack_reconfigure"

  def self.base_model
    OrchestrationStackReconfigureTask
  end

  def self.request_class
    ServiceReconfigureRequest
  end

  def stack
    source
  end

  def do_request
    signal :run_reconfigure
  end

  # Called by WorkflowInstance#run before the workflow starts executing.
  # Transitions the task to "active" so the parent ServiceReconfigureTask
  # rolls up a "provisioning" lifecycle_state on the Service.
  def before_ae_starts(_options)
    reload
    if state.to_s.downcase.in?(%w[pending queued])
      _log.info("Executing #{request_class::TASK_DESCRIPTION} request: [#{description}]")
      update_and_notify_parent(:state => "active", :status => "Ok", :message => "In Process")
    end
  end

  # Called by WorkflowInstance#run after the workflow finishes.
  # Translates the workflow ae_result into a finished state so the parent
  # ServiceReconfigureTask rolls up the final lifecycle_state on the Service.
  def after_ae_delivery(ae_result)
    _log.info("ae_result=#{ae_result.inspect}")

    return if ae_result == 'retry'
    return if miq_request.state == 'finished'

    if ae_result == 'ok'
      update_and_notify_parent(:state   => "finished",
                               :status  => "Ok",
                               :message => "#{request_class::TASK_DESCRIPTION} completed")
    else
      update_and_notify_parent(:state   => "finished",
                               :status  => "Error",
                               :message => "#{request_class::TASK_DESCRIPTION} failed")
    end
  end
end
