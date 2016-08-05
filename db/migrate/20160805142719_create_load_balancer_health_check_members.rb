class CreateLoadBalancerHealthCheckMembers < ActiveRecord::Migration[5.0]
  def change
    create_table :load_balancer_health_check_members do |t|
      t.belongs_to :load_balancer_health_check, :type => :bigint, :index => { :name => 'members_load_balancer_health_check_index' }
      t.belongs_to :load_balancer_pool_member,  :type => :bigint, :index => { :name => 'members_load_balancer_pool_member_index' }
    end

    add_index :load_balancer_health_check_members,
              [:load_balancer_health_check_id, :load_balancer_pool_member_id],
              :name => 'load_balancer_health_check_members_index'
  end
end
