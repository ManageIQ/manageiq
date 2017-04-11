class AddScmUpdateCacheTimeoutToConfigurationScriptSource < ActiveRecord::Migration[5.0]
  def change
    add_column :configuration_script_sources, :scm_update_cache_timeout, :integer
  end
end
