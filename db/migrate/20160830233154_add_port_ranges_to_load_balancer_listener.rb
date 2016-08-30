class AddPortRangesToLoadBalancerListener < ActiveRecord::Migration[5.0]
  def change
    change_table :load_balancer_listeners do |t|
      t.column :load_balancer_port_range, :int4range
      t.column :instance_port_range, :int4range
    end
  end
end
