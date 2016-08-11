class AddLoadBalancerIdToLoadBalancerHealthChecks < ActiveRecord::Migration[5.0]
  def change
    add_column :load_balancer_health_checks, :load_balancer_id, :bigint
    add_index :load_balancer_health_checks, :load_balancer_id
  end
end
