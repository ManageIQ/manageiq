class OrchestrationTemplate
  class OrchestrationParameterGroup
    attr_accessor :description, :label, :parameters

    def initialize(hash = {})
      hash.each { |key, value| public_send(:"#{key}=", value) }
    end
  end
end
