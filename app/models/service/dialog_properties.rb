class Service
  class DialogProperties
    require_nested :Retirement

    def initialize(options, user)
      @options = options || {}
      @user = user
    end

    def self.parse(options, user)
      new(options, user).parse
    end

    def parse
      Service::DialogProperties::Retirement.parse(@options, @user).tap do |attributes|
        attributes[:name] = @options['dialog_service_name'] if @options['dialog_service_name'].present?
        attributes[:description] = @options['dialog_service_description'] if @options['dialog_service_description'].present?
      end
    end
  end
end
