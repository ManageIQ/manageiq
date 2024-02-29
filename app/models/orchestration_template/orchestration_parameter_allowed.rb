class OrchestrationTemplate
  class OrchestrationParameterAllowed < OrchestrationParameterConstraint
    attr_accessor :allowed_values, :allow_multiple
  end
end
