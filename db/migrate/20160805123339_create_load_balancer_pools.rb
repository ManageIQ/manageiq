class CreateLoadBalancerPools < ActiveRecord::Migration[5.0]
  def change
    create_table :load_balancer_pools do |t|
      t.string  :ems_ref
      t.string  :name
      t.string  :description
      t.string  :load_balancer_algorithm
      t.string  :protocol

      t.belongs_to :ems,          :type => :bigint
      t.belongs_to :cloud_tenant, :type => :bigint

      t.timestamps
    end

    add_index :load_balancer_pools, :ems_ref
  end
end
