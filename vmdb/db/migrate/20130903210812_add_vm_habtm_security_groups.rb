class AddVmHabtmSecurityGroups < ActiveRecord::Migration
  def change
    create_table :security_groups_vms, :id => false do |t|
      t.references :security_group
      t.references :vm
    end
  end
end
