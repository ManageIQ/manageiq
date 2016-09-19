class AddTenantRelationshipToObjects < ActiveRecord::Migration[5.0]
  def change
    add_column :security_groups,               :tenant_id, :bigint
    add_column :floating_ips,                  :tenant_id, :bigint
    add_column :cloud_networks,                :tenant_id, :bigint
    add_column :cloud_subnets,                 :tenant_id, :bigint
    add_column :cloud_resource_quotas,         :tenant_id, :bigint
    add_column :cloud_object_store_containers, :tenant_id, :bigint
    add_column :cloud_object_store_objects,    :tenant_id, :bigint
    add_column :network_ports,                 :tenant_id, :bigint
    add_column :network_routers,               :tenant_id, :bigint
    add_column :cloud_volumes,                 :tenant_id, :bigint
    add_column :cloud_volume_snapshots,        :tenant_id, :bigint
    add_column :cloud_volume_backups,          :tenant_id, :bigint
    add_column :cloud_volume_backups,          :cloud_tenant_id, :bigint

    create_table :tenant_flavors do |t|
      t.column :tenant_id, :bigint
      t.column :flavor_id, :bigint
    end
    add_index :tenant_flavors, [:tenant_id, :flavor_id], :unique => true
  end
end
