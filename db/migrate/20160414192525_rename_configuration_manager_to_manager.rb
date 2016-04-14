class RenameConfigurationManagerToManager < ActiveRecord::Migration[5.0]
  def change
    rename_column :configuration_profiles, :configuration_manager_id, :manager_id
    rename_column :configuration_scripts,  :configuration_manager_id, :manager_id
    rename_column :configured_systems,     :configuration_manager_id, :manager_id
  end
end
