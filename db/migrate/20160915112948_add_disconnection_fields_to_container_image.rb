class AddDisconnectionFieldsToContainerImage < ActiveRecord::Migration[5.0]
  def change
    add_column :container_images, :old_ems_id, :bigint
    add_column :container_images, :deleted_on, :datetime
  end
end
