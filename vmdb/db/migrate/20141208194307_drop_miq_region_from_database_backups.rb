class DropMiqRegionFromDatabaseBackups < ActiveRecord::Migration
  def up
    remove_column :database_backups, :miq_region_id
  end

  def down
    add_column :database_backups, :miq_region_id, :bigint
  end
end
