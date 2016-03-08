class DeleteNetworkRouterIdFromFloatingIps < ActiveRecord::Migration
  def up
    remove_index :floating_ips, :column => :network_router_id
    remove_column :floating_ips, :network_router_id, :bigint
  end

  def down
    add_column :floating_ips, :network_router_id, :bigint
    add_index :floating_ips, :network_router_id
  end
end
