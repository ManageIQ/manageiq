class Service
  class DialogProperties
    def initialize(options)
      @options = options || {}
    end

    def self.parse(options)
      new(options).parse
    end

    def parse
      {}.tap do |attributes|
        attributes[:name] = @options['dialog_service_name'] if @options['dialog_service_name'].present?
        attributes[:description] = @options['dialog_service_description'] if @options['dialog_service_description'].present?
      end
    end
  end
end
