class AddDiskInfoToFlavors < ActiveRecord::Migration[4.2]
  def change
    add_column :flavors, :disk_size, :bigint
    add_column :flavors, :disk_count, :integer
  end
end
