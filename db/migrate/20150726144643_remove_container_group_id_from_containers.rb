class RemoveContainerGroupIdFromContainers < ActiveRecord::Migration[4.2]
  def change
    remove_column :containers, :container_group_id, :bigint
  end
end
