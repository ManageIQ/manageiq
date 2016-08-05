class CreateLoadBalancerListeners < ActiveRecord::Migration[5.0]
  def change
    create_table :load_balancer_listeners do |t|
      t.string  :ems_ref
      t.string  :name
      t.string  :description
      t.string  :load_balancer_protocol
      t.integer :load_balancer_port
      t.string  :instance_protocol
      t.integer :instance_port

      t.belongs_to :ems,                :type => :bigint
      t.belongs_to :cloud_tenant,       :type => :bigint
      t.belongs_to :load_balancer,      :type => :bigint
      t.belongs_to :load_balancer_pool, :type => :bigint
      t.belongs_to :network_port,       :type => :bigint

      t.timestamps
    end

    add_index :load_balancer_listeners, :ems_ref
  end
end
