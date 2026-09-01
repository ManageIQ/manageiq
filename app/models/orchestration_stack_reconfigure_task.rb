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
end
