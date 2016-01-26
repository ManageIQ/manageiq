class AddNetworkGroupIdToSecurityGroups < ActiveRecord::Migration
  def change
    add_column :security_groups, :network_group_id, :bigint

    add_index :security_groups, :network_group_id
  end
end
