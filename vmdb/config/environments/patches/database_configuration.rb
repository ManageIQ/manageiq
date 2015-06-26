# Patches the database_configuration method to not evaluate ERB in production
# mode for security purposes.  Also, adds support to handle encrypted
# password fields as strings without ERB.
#
# The original implementation is as follows:
#
#    def database_configuration
#      require 'erb'
#      YAML::load(ERB.new(IO.read(paths["config/database"].first)).result)
#    end
require 'rails/application/configuration'
Rails::Application::Configuration.module_eval do
  # sorry for the multi line {}
  # block needs to be associated with module not prepend
  prepend Module.new {
    def database_configuration
      path = paths["config/database"].existent.first
      yaml = Pathname.new(path) if path

      if yaml && yaml.exist?
        Vmdb::ConfigurationEncoder.load(IO.read(yaml), false)
      else
        super
      end
    end
  }
end
