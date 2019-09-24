class OrchestrationTemplate
  class OrchestrationParameterConstraint
    attr_accessor :description

    def initialize(hash = {})
      hash.each { |key, value| public_send("#{key}=", value) }
    end
  end
end
