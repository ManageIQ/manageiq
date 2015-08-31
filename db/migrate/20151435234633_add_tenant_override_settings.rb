class AddTenantOverrideSettings < ActiveRecord::Migration
  def change
    add_column :tenants, :use_config_for_attributes, :boolean
  end
end
