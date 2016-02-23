class DeleteCloudNetworkIdFromNetworkPorts < ActiveRecord::Migration
  def up
    remove_index :network_ports, :column => :cloud_network_id
    remove_column :network_ports, :cloud_network_id, :bigint
  end

  def down
    add_column :network_ports, :cloud_network_id, :bigint
    add_index :network_ports, :cloud_network_id
  end
end
