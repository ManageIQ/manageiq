class AddContainerGroupIpToContainerGroups < ActiveRecord::Migration
  def up
    add_column :container_groups, :ipaddress, :string
  end

  def down
    remove_column :container_groups, :ipaddress
  end
end
