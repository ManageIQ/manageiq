class AddNetworkGroupIdToCloudSubnets < ActiveRecord::Migration
  def change
    add_column :cloud_subnets, :network_group_id, :bigint

    add_index :cloud_subnets, :network_group_id
  end
end
