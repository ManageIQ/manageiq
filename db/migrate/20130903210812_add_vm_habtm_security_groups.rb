class AddVmHabtmSecurityGroups < ActiveRecord::Migration
  def change
    create_table :security_groups_vms, :id => false do |t|
      t.references :security_group, :type => :bigint
      t.references :vm, :type => :bigint
    end
  end
end
