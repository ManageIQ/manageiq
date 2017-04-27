# Patches the database_configuration method to not evaluate ERB in production
# mode for security purposes.  Also, adds support to handle encrypted
# password fields as strings without ERB.

require 'rails/application/configuration'
Rails::Application::Configuration.module_eval do
  prepend MiqDbConfig
end
