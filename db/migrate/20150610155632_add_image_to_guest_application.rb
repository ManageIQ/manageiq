class AddImageToGuestApplication < ActiveRecord::Migration
  def change
    add_column :guest_applications, :container_image_id, :bigint
  end
end
