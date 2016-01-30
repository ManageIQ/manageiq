class AddResourceGroupIdToVms < ActiveRecord::Migration
  def up
    add_column :vms, :resource_group_id, :bigint
  end

  def down
    remove_column :vms, :resource_group_id
  end
end
