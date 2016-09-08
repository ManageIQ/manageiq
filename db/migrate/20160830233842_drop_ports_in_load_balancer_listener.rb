class DropPortsInLoadBalancerListener < ActiveRecord::Migration[5.0]
  def change
    remove_column :load_balancer_listeners, :load_balancer_port, :integer
    remove_column :load_balancer_listeners, :instance_port, :integer
  end
end
