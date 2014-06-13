class AddPathToPxeImages < ActiveRecord::Migration
  def change
    add_column :pxe_images, :path, :string
  end
end
