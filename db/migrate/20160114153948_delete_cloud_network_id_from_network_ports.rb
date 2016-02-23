class DeleteCloudNetworkIdFromNetworkPorts < ActiveRecord::Migration
  def change
    remove_column :network_ports, :cloud_network_id, :bigint
  end
end
