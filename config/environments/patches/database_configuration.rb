# Patches the database_configuration method to not evaluate ERB in production
# mode for security purposes.  Also, adds support to handle encrypted
# password fields as strings without ERB.

require 'rails/application/configuration'
require 'patches/database_configuration_patch'

Rails::Application::Configuration.module_eval do
  prepend DatabaseConfigurationPatch
end
