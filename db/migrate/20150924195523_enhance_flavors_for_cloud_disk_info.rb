class EnhanceFlavorsForCloudDiskInfo < ActiveRecord::Migration
  def change
    add_column :flavors, :root_disk_size, :bigint
    add_column :flavors, :swap_disk_size, :bigint
    rename_column :flavors, :disk_size, :ephemeral_disk_size
    rename_column :flavors, :disk_count, :ephemeral_disk_count
  end
end
