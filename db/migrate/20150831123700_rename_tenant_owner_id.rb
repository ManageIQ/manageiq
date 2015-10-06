class RenameTenantOwnerId < ActiveRecord::Migration
  def change
    rename_column :ext_management_systems, :tenant_owner_id, :tenant_id
    rename_column :miq_groups, :tenant_owner_id, :tenant_id
    rename_column :providers, :tenant_owner_id, :tenant_id
    rename_column :vms, :tenant_owner_id, :tenant_id
  end
end
