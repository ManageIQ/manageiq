class AddContainerGroupIpToContainerGroups < ActiveRecord::Migration[4.2]
  def up
    add_column :container_groups, :ipaddress, :string
  end

  def down
    remove_column :container_groups, :ipaddress
  end
end
