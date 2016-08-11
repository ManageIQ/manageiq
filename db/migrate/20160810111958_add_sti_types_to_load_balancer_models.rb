class AddStiTypesToLoadBalancerModels < ActiveRecord::Migration[5.0]
  def change
    add_column :load_balancers, :type, :string
    add_column :load_balancer_pools, :type, :string
    add_column :load_balancer_pool_members, :type, :string
    add_column :load_balancer_listeners, :type, :string
    add_column :load_balancer_health_checks, :type, :string
  end
end
