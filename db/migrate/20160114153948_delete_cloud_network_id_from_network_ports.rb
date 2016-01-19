class DeleteCloudNetworkIdFromNetworkPorts < ActiveRecord::Migration
  def change
    remove_index :network_ports, :column => :cloud_network_id
    remove_column :network_ports, :cloud_network_id, :bigint
  end
end
