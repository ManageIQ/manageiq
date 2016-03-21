class RemoveCloudSubnetIdFromNetworkPort < ActiveRecord::Migration[5.0]
  def up
    remove_column :network_ports, :cloud_subnet_id
  end

  def down
    add_column :network_ports, :cloud_subnet_id, :bigint
    add_index :network_ports, :cloud_subnet_id
  end
end
