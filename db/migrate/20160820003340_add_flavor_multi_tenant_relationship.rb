class AddFlavorMultiTenantRelationship < ActiveRecord::Migration[5.0]
  def change
    create_table :cloud_tenants_flavors do |t|
      t.column :cloud_tenant_id, :bigint
      t.column :flavor_id, :bigint
    end
    add_column :flavors, :publicly_available, :boolean
    add_index :cloud_tenants_flavors, [:cloud_tenant_id, :flavor_id], :unique => true
  end
end
