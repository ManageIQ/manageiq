class RenameMiqCimStatsToMiqStorageStats < ActiveRecord::Migration
  def self.up
    rename_table  :miq_cim_stats, :miq_storage_stats
  end

  def self.down
    rename_table  :miq_storage_stats, :miq_cim_stats
  end
end
