class AddVmIdToLoadBalancerPoolMembers < ActiveRecord::Migration[5.0]
  def change
    add_column :load_balancer_pool_members, :vm_id, :bigint
    add_index :load_balancer_pool_members, :vm_id
  end
end
