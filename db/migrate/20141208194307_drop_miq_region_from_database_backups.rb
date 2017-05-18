class DropMiqRegionFromDatabaseBackups < ActiveRecord::Migration[4.2]
  def up
    remove_index  :database_backups, :miq_region_id
    remove_column :database_backups, :miq_region_id
  end

  def down
    add_column :database_backups, :miq_region_id, :bigint
    add_index  :database_backups, :miq_region_id
  end
end
