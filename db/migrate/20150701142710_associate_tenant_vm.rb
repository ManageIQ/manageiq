class AssociateTenantVm < ActiveRecord::Migration[4.2]
  def change
    add_column :providers, :tenant_owner_id, :bigint
    add_column :vms, :tenant_owner_id, :bigint
    add_column :ext_management_systems, :tenant_owner_id, :bigint
    add_column :miq_groups, :tenant_owner_id, :bigint
  end
end
