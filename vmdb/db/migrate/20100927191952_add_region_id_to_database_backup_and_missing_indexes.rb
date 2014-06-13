class AddRegionIdToDatabaseBackupAndMissingIndexes < ActiveRecord::Migration
  def self.up
    add_column    :database_backups, :miq_region_id,  :bigint
    add_index     :database_backups, :miq_region_id

    change_column :file_depots, :resource_id, :bigint
    add_index     :file_depots, [:resource_id, :resource_type]
  end

  def self.down
    remove_index  :database_backups, :miq_region_id
    remove_column :database_backups, :miq_region_id

    remove_index  :file_depots, [:resource_id, :resource_type]
    change_column :file_depots, :resource_id, :integer
  end
end
