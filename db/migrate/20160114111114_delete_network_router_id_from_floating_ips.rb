class DeleteNetworkRouterIdFromFloatingIps < ActiveRecord::Migration
  def change
    remove_index :floating_ips, :column => :network_router_id
    remove_column :floating_ips, :network_router_id, :bigint
  end
end
