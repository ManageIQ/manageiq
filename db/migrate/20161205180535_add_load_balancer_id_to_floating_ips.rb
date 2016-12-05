class AddLoadBalancerIdToFloatingIps < ActiveRecord::Migration[5.0]
  def change
    add_column :floating_ips, :load_balancer_id, :bigint
  end
end
