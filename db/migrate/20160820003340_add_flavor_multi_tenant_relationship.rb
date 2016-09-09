class AddFlavorMultiTenantRelationship < ActiveRecord::Migration[5.0]
  def change
    create_table :cloud_tenant_flavors do |t|
      t.column :cloud_tenant_id, :bigint
      t.column :flavor_id, :bigint
    end
    add_column :flavors, :publicly_available, :boolean
    add_index :cloud_tenant_flavors, [:cloud_tenant_id, :flavor_id], :unique => true
  end
end
