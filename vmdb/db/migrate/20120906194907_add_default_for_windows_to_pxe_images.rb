class AddDefaultForWindowsToPxeImages < ActiveRecord::Migration
  def change
    add_column :pxe_images, :default_for_windows, :boolean
  end
end
