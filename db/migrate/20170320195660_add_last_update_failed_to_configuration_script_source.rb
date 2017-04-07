class AddLastUpdateFailedToConfigurationScriptSource < ActiveRecord::Migration[5.0]
  def change
    add_column :configuration_script_sources, :last_update_failed, :boolean
  end
end
