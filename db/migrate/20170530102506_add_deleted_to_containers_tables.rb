class AddDeletedToContainersTables < ActiveRecord::Migration[5.0]
  def change
    add_index :container_definitions, :deleted_on,
              :name  => "index_container_definitions_on_deleted_on"
    add_index :container_groups, :deleted_on,
              :name  => "container_groups_on_deleted_on"
    add_index :container_images, :deleted_on,
              :name  => "index_container_images_on_deleted_on"
    add_index :container_projects, :deleted_on,
              :name  => "index_container_projects_on_deleted_on"
    add_index :containers, :deleted_on,
              :name  => "index_containers_on_deleted_on"
  end
end
