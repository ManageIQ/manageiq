module MiqDbConfig
  def database_configuration
    path = File.join(__dir__, "../config/database.yml")
    yaml = Pathname.new(path) if File.exists?(path)

    if yaml && yaml.exist?
      require "yaml"
      require "erb"

      not_production = !(ENV["RAILS_ENV"] == "production")

      data = yaml.read
      data = ERB.new(data).result if not_production || ENV['ERB_IN_CONFIG']

      begin
        data = YAML.load(data) || {}
      rescue Psych::SyntaxError => e
        raise "YAML syntax error occurred while parsing #{paths["config/database"].first}. " \
              "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
              "Error: #{e.message}"
      rescue => e
        raise e, "Cannot load `Rails.application.database_configuration`:\n#{e.message}", e.backtrace
      end

      if defined? Vmbd::Settings
        Vmdb::Settings.decrypt_passwords!(data)
      else
        data
      end
    else
      super
    end
  end
end
