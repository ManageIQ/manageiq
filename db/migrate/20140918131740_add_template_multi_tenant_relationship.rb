class AddTemplateMultiTenantRelationship < ActiveRecord::Migration[4.2]
  def up
    create_table :cloud_tenants_vms, :id => false do |t|
      t.column :cloud_tenant_id, :bigint
      t.column :vm_id, :bigint
    end
  end

  def down
    drop_table :cloud_tenants_vms
  end
end
