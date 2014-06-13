class AddStorageIdToDisks < ActiveRecord::Migration
  def self.up
    add_column :disks, :storage_id, :integer
  end

  def self.down
    remove_column :disks, :storage_id
  end
end
