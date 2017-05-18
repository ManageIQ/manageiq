class MigrateConfigurationScriptToBase < ActiveRecord::Migration[5.0]
  class ServiceResource < ActiveRecord::Base
  end

  def up
    say_with_time('Migrating service_resources configuration_script to configuration_script_base') do
      ServiceResource
        .where(:resource_type => 'ConfigurationScript')
        .update_all(:resource_type => 'ConfigurationScriptBase')
    end
  end

  def down
    say_with_time('Migrating service_resources configuration_script_base to configuration_script') do
      ServiceResource
        .where(:resource_type => 'ConfigurationScriptBase')
        .update_all(:resource_type => 'ConfigurationScript')
    end
  end
end
