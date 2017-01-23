class AddLoadBalancerIdToNetworkPorts < ActiveRecord::Migration[5.0]
  def change
    add_column :network_ports, :load_balancer_id, :bigint
  end
end
