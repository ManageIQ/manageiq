class AddMissingFieldsAndIndexesToFloatingIps < ActiveRecord::Migration
  def change
    add_column :floating_ips, :network_router_id, :bigint
    add_column :floating_ips, :network_port_id,   :bigint
    add_column :floating_ips, :cloud_network_id,  :bigint
    add_column :floating_ips, :fixed_ip_address,  :string

    add_index :floating_ips, :ems_id
    add_index :floating_ips, :cloud_tenant_id
    add_index :floating_ips, :network_router_id
    add_index :floating_ips, :network_port_id
    add_index :floating_ips, :cloud_network_id
  end
end
