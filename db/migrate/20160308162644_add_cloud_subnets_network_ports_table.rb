class AddCloudSubnetsNetworkPortsTable < ActiveRecord::Migration[5.0]
  def change
    create_table :cloud_subnets_network_ports do |t|
      t.belongs_to :cloud_subnet, :type => :bigint
      t.belongs_to :network_port, :type => :bigint
      t.string     :address
    end

    add_index :cloud_subnets_network_ports, ["cloud_subnet_id", "network_port_id"], :name => "index_cloud_subnets_network_ports", :unique => true
  end
end
