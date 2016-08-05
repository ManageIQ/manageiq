class CreateLoadBalancerPoolMembers < ActiveRecord::Migration[5.0]
  def change
    create_table :load_balancer_pool_members do |t|
      t.string  :ems_ref
      t.string  :address
      t.integer :port

      t.belongs_to :cloud_tenant,   :type => :bigint
      t.belongs_to :cloud_subnet,   :type => :bigint
      t.belongs_to :network_port,   :type => :bigint
      t.belongs_to :resource_group, :type => :bigint

      t.timestamps
    end

    add_index :load_balancer_pool_members, :ems_ref
  end
end
