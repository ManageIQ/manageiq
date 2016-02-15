class AddContainerImageRegistryToContainerService < ActiveRecord::Migration
  def change
    add_column :container_services, :container_image_registry_id, :bigint
  end
end
