class AddStorageIdToIsoImages < ActiveRecord::Migration
  def change
    add_column :iso_images, :storage_id, :bigint
  end
end
