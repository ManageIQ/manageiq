unless defined?(Rails)
  module Rails
    def self.rails_root
      @rails_root ||= ENV["RAILS_ROOT"]
    end

    def self.env
      @env ||= ActiveSupport::StringInquirer.new("production")
    end
  end
end
