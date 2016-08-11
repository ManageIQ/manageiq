class ChangeLoadBalancerMToNTablesIndexesToUnique < ActiveRecord::Migration[5.0]
  def change
    remove_index :load_balancer_health_check_members,
                 :column => [:load_balancer_health_check_id, :load_balancer_pool_member_id],
                 :name   => 'load_balancer_health_check_members_index'

    add_index :load_balancer_health_check_members,
              [:load_balancer_health_check_id, :load_balancer_pool_member_id],
              :name   => 'load_balancer_health_check_members_index',
              :unique => true

    remove_index :load_balancer_listener_pools,
                 :column => [:load_balancer_listener_id, :load_balancer_pool_id],
                 :name   => 'load_balancer_listener_pools_index'

    add_index :load_balancer_listener_pools,
              [:load_balancer_listener_id, :load_balancer_pool_id],
              :name   => 'load_balancer_listener_pools_index',
              :unique => true
  end
end
