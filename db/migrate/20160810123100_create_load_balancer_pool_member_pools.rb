class CreateLoadBalancerPoolMemberPools < ActiveRecord::Migration[5.0]
  def change
    create_table :load_balancer_pool_member_pools do |t|
      t.belongs_to :load_balancer_pool, :type => :bigint, :index => {:name => 'load_balancer_pool_index'}
      t.belongs_to :load_balancer_pool_member, :type => :bigint, :index => {:name => 'load_balancer_pool_member_index'}
    end

    add_index :load_balancer_pool_member_pools,
              [:load_balancer_pool_id, :load_balancer_pool_member_id],
              :name   => 'load_balancer_pool_member_pools_index',
              :unique => true
  end
end
