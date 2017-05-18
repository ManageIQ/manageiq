class AddBlockStorageOnlyToFlavor < ActiveRecord::Migration[4.2]
  def change
    add_column :flavors, :block_storage_based_only, :boolean
  end
end
