class AddDeletedToContainersTables < ActiveRecord::Migration[5.0]
  def change
    add_column :container_definitions, :deleted, :boolean, :default => false, :null => false
    add_column :container_groups, :deleted, :boolean, :default => false, :null => false
    add_column :container_images, :deleted, :boolean, :default => false, :null => false
    add_column :container_projects, :deleted, :boolean, :default => false, :null => false
    add_column :containers, :deleted, :boolean, :default => false, :null => false

    add_index :container_definitions, :deleted,
              :name  => "index_container_definitions_on_deleted_false",
              :where => "NOT deleted"
    add_index :container_groups, :deleted,
              :name  => "container_groups_on_deleted_false",
              :where => "NOT deleted"
    add_index :container_images, :deleted,
              :name  => "index_container_images_on_deleted_false",
              :where => "NOT deleted"
    add_index :container_projects, :deleted,
              :name  => "index_container_projects_on_deleted_false",
              :where => "NOT deleted"
    add_index :containers, :deleted,
              :name  => "index_containers_on_deleted_false",
              :where => "NOT deleted"
  end
end
