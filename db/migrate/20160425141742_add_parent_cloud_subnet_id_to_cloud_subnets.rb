class AddParentCloudSubnetIdToCloudSubnets < ActiveRecord::Migration[5.0]
  def change
    add_column :cloud_subnets, :parent_cloud_subnet_id, :bigint

    add_index :cloud_subnets, :parent_cloud_subnet_id
  end
end
