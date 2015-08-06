class RemoveContainerGroupIdFromContainers < ActiveRecord::Migration
  def change
    remove_column :containers, :container_group_id, :bigint
  end
end
