class CreateLoadBalancerListenerPools < ActiveRecord::Migration[5.0]
  def change
    create_table :load_balancer_listener_pools do |t|
      t.belongs_to :load_balancer_listener, :type => :bigint
      t.belongs_to :load_balancer_pool,     :type => :bigint

      t.timestamps
    end

    add_index :load_balancer_listener_pools,
              [:load_balancer_listener_id, :load_balancer_pool_id],
              :name => 'load_balancer_listener_pools_index'
  end
end
