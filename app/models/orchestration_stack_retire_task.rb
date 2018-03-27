class OrchestrationStackRetireTask < MiqRetireTask
  def self.base_model
    OrchestrationStackRetireTask
  end

  def self.model_being_retired
    OrchestrationStack
  end
end
