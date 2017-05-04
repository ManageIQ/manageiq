class AddContainerImageRegistryToContainerService < ActiveRecord::Migration[4.2]
  def change
    add_column :container_services, :container_image_registry_id, :bigint
  end
end
