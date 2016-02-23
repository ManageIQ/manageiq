class DeleteNetworkRouterIdFromFloatingIps < ActiveRecord::Migration
  def change
    remove_column :floating_ips, :network_router_id, :bigint
  end
end
