class RemoveLoadBalancerPoolIdAndNetworkPortIdFromLoadBalancerListeners < ActiveRecord::Migration[5.0]
  def up
    remove_column :load_balancer_listeners, :load_balancer_pool_id
    remove_column :load_balancer_listeners, :network_port_id
  end

  def down
    add_column :load_balancer_listeners, :load_balancer_pool_id, :bigint
    add_column :load_balancer_listeners, :network_port_id, :bigint

    add_index :load_balancer_listeners, :load_balancer_pool_id
    add_index :load_balancer_listeners, :network_port_id
  end
end
