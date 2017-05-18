class AddScmAttributesToConfigurationScriptSource < ActiveRecord::Migration[5.0]
  def change
    add_column :configuration_script_sources, :scm_type,             :string
    add_column :configuration_script_sources, :scm_url,              :string
    add_column :configuration_script_sources, :scm_branch,           :string
    add_column :configuration_script_sources, :scm_clean,            :boolean
    add_column :configuration_script_sources, :scm_delete_on_update, :boolean
    add_column :configuration_script_sources, :scm_update_on_launch, :boolean
    add_column :configuration_script_sources, :authentication_id,    :bigint
  end
end
