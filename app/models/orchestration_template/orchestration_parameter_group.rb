class OrchestrationTemplate
  class OrchestrationParameterGroup
    attr_accessor :description
    attr_accessor :label
    attr_accessor :parameters

    def initialize(hash = {})
      hash.each { |key, value| public_send("#{key}=", value) }
    end
  end
end
