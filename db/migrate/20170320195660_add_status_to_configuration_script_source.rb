class AddStatusToConfigurationScriptSource < ActiveRecord::Migration[5.0]
  def change
    add_column :configuration_script_sources, :status, :string
  end
end
