class OrchestrationTemplate
  class OrchestrationParameterAllowed < OrchestrationParameterConstraint
    attr_accessor :allowed_values
    attr_accessor :allow_multiple
  end
end
