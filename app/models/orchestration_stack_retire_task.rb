class OrchestrationStackRetireTask < MiqRetireTask
  attribute :request_type, :default => "orchestration_stack_retire"

  def self.base_model
    OrchestrationStackRetireTask
  end

  def self.model_being_retired
    OrchestrationStack
  end
end
