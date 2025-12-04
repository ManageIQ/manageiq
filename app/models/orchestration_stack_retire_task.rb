class OrchestrationStackRetireTask < MiqRetireTask
  include StateMachine

  default_value_for :request_type, "orchestration_stack_retire"

  def stack
    source
  end

  def self.base_model
    OrchestrationStackRetireTask
  end

  def self.model_being_retired
    OrchestrationStack
  end
end
