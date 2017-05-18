class AddConfigurationScriptPayloadAndConfigurationScriptSourceToConfigurationScripts < ActiveRecord::Migration[5.0]
  def change
    add_column :configuration_scripts, :parent_id,                        :bigint
    add_column :configuration_scripts, :configuration_script_source_id,   :bigint
  end
end
