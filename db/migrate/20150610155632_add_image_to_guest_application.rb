class AddImageToGuestApplication < ActiveRecord::Migration[4.2]
  def change
    add_column :guest_applications, :container_image_id, :bigint
  end
end
