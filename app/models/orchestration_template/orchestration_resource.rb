class OrchestrationTemplate
  class OrchestrationResource
    attr_accessor :name
    attr_accessor :type

    def initialize(hash = {})
      hash.each { |key, value| public_send("#{key}=", value) }
    end
  end
end
