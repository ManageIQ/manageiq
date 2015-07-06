class CreateFloatingIps < ActiveRecord::Migration
  def change
    create_table :floating_ips do |t|
      t.string :type
      t.string :ems_ref
      t.string :address
      t.bigint :ems_id
      t.bigint :vm_id
    end
  end
end
