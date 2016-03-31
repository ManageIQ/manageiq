class AddRegisteredOnToContainerImage < ActiveRecord::Migration[5.0]
  def change
    add_column :container_images, :registered_on, :datetime
  end
end
