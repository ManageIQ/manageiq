class AddNetworkGroupIdToSecurityGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :security_groups, :network_group_id, :bigint

    add_index :security_groups, :network_group_id
  end
end
