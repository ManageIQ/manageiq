class CreateLoadBalancers < ActiveRecord::Migration[5.0]
  def change
    create_table :load_balancers do |t|
      t.string  :ems_ref
      t.string  :name
      t.string  :description

      t.belongs_to :ems,          :type => :bigint
      t.belongs_to :cloud_tenant, :type => :bigint

      t.timestamps
    end

    add_index :load_balancers, :ems_ref
  end
end
