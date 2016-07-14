class AddStorageProfileIdToDisks < ActiveRecord::Migration[5.0]
  def change
    add_column :disks, :storage_profile_id, :bigint
  end
end
