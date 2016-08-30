class ChangeCloudSubnetsNetworkPortsUniqueIndex < ActiveRecord::Migration[5.0]
  def change
    remove_index :cloud_subnets_network_ports,
                 :column => [:cloud_subnet_id, :network_port_id],
                 :name   => 'index_cloud_subnets_network_ports',
                 :unique => true

    add_index :cloud_subnets_network_ports, :address

    add_index :cloud_subnets_network_ports,
              [:cloud_subnet_id, :network_port_id, :address],
              :name   => 'index_cloud_subnets_network_ports_address',
              :unique => true
  end
end
