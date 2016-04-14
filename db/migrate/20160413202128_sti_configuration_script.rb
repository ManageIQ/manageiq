class StiConfigurationScript < ActiveRecord::Migration[5.0]
  class ConfigurationScript < ApplicationRecord
    self.inheritance_column = :_type_disabled
  end

  def up
    add_column :configuration_scripts, :type, :string

    say_with_time("Setting type on ConfigurationScript") do
      ConfigurationScript.update_all(:type => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript")
    end
  end

  def down
    remove_column :configuration_scripts, :type
  end
end
