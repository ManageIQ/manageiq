class AddContainerNodeMaxContainerGroup < ActiveRecord::Migration[4.2]
  def change
    add_column :container_nodes, :max_container_groups, :int
  end
end
