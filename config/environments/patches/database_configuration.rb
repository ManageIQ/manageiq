# Patches the database_configuration method to not evaluate ERB in production
# mode for security purposes.  Also, adds support to handle encrypted
# password fields as strings without ERB.

require 'rails/application/configuration'
Rails::Application::Configuration.module_eval do
  prepend Module.new {
    def database_configuration
      path = paths["config/database"].existent.first
      yaml = Pathname.new(path) if path

      if yaml && yaml.exist?
        require "yaml"
        require "erb"

        data = yaml.read
        data = ERB.new(data).result unless Rails.env.production?

        begin
          data = YAML.load(data) || {}
        rescue Psych::SyntaxError => e
          raise "YAML syntax error occurred while parsing #{paths["config/database"].first}. " \
                "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
                "Error: #{e.message}"
        rescue => e
          raise e, "Cannot load `Rails.application.database_configuration`:\n#{e.message}", e.backtrace
        end

        Vmdb::Settings.decrypt_passwords!(data)
      else
        super
      end
    end
  }
end
