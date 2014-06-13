class RenameOsImagesToPxeImages < ActiveRecord::Migration
  def self.up
    rename_table  :os_images, :pxe_images

    rename_column :pxe_images, :tftp_server_id, :pxe_server_id

    add_column    :pxe_images, :options, :text

    remove_column :pxe_images, :path
    remove_column :pxe_images, :mtime
    remove_column :pxe_images, :size
  end

  def self.down
    add_column    :pxe_images, :size,   :integer,   :limit => 8
    add_column    :pxe_images, :mtime,  :datetime
    add_column    :pxe_images, :path,   :string

    remove_column :pxe_images, :options

    rename_column :pxe_images, :pxe_server_id, :tftp_server_id

    rename_table  :pxe_images, :os_images
  end
end
