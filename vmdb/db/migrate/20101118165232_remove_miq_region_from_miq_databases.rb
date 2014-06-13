class RemoveMiqRegionFromMiqDatabases < ActiveRecord::Migration
  def self.up
    remove_column :miq_databases,  :miq_region_id
  end

  def self.down
    add_column  :miq_databases, :miq_region_id, :bigint
  end
end
