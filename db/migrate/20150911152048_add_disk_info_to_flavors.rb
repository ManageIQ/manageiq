class AddDiskInfoToFlavors < ActiveRecord::Migration
  def change
    add_column :flavors, :disk_size, :bigint
    add_column :flavors, :disk_count, :integer
  end
end
