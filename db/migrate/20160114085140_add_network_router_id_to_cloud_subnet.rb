class AddNetworkRouterIdToCloudSubnet < ActiveRecord::Migration
  def change
    add_column :cloud_subnets, :network_router_id, :bigint
  end
end
