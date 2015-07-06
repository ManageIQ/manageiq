class AddBlockStorageOnlyToFlavor < ActiveRecord::Migration
  def change
    add_column :flavors, :block_storage_based_only, :boolean
  end
end
