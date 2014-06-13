class AddStiToPxeMenusAndPxeImages < ActiveRecord::Migration
  def change
    add_column :pxe_menus,  :type, :string
    add_column :pxe_images, :type, :string
  end
end
