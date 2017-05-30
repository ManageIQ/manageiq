class AddDeletedToContainersTables < ActiveRecord::Migration[5.0]
  def change
    add_column :container_definitions, :deleted, :boolean, :default => false, :null => false
    add_column :container_groups, :deleted, :boolean, :default => false, :null => false
    add_column :container_images, :deleted, :boolean, :default => false, :null => false
    add_column :container_projects, :deleted, :boolean, :default => false, :null => false
    add_column :containers, :deleted, :boolean, :default => false, :null => false
  end
end
