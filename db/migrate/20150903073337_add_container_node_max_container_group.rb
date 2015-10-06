class AddContainerNodeMaxContainerGroup < ActiveRecord::Migration
  def change
    add_column :container_nodes, :max_container_groups, :int
  end
end
