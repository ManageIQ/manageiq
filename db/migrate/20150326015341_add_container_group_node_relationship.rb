class AddContainerGroupNodeRelationship < ActiveRecord::Migration[4.2]
  def change
    add_column :container_groups, :container_node_id, :bigint
  end
end
