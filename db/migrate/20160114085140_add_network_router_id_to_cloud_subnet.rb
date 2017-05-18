class AddNetworkRouterIdToCloudSubnet < ActiveRecord::Migration[4.2]
  def change
    add_column :cloud_subnets, :network_router_id, :bigint
  end
end
