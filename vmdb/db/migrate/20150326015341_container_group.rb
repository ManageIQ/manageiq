class ContainerGroup < ActiveRecord::Migration
  def change
    add_column :container_groups, :container_node_id, :bigint
  end
end
