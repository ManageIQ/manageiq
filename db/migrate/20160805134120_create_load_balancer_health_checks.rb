class CreateLoadBalancerHealthChecks < ActiveRecord::Migration[5.0]
  def change
    create_table :load_balancer_health_checks do |t|
      t.string  :ems_ref
      t.string  :name

      t.string  :protocol
      t.integer :port
      t.string  :url_path
      t.integer :interval
      t.integer :timeout
      t.integer :healthy_threshold
      t.integer :unhealthy_threshold

      t.belongs_to :ems,                    :type => :bigint
      t.belongs_to :load_balancer_listener, :type => :bigint
      t.belongs_to :cloud_tenant,           :type => :bigint

      t.timestamps
    end

    add_index :load_balancer_health_checks, :ems_ref
  end
end
