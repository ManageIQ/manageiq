class AddDiskAndMemoryMinimumToHardware < ActiveRecord::Migration
  def change
    add_column :hardwares, :disk_size_minimum, :integer, :limit => 8
    add_column :hardwares, :memory_mb_minimum, :integer, :limit => 8
  end
end
