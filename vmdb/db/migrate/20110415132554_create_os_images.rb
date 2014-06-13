class CreateOsImages < ActiveRecord::Migration
  def self.up
    create_table :os_images do |t|
      t.string      :name
      t.string      :description
      t.bigint      :tftp_server_id
      t.string      :path
      t.datetime    :mtime
      t.integer     :size,        :limit => 8
      t.timestamps
    end
  end

  def self.down
    drop_table :os_images
  end
end
