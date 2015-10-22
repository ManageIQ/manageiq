class AddTenantDefaultGroup < ActiveRecord::Migration
  def change
    add_column :tenants, :default_miq_group_id, :bigint
  end
end
