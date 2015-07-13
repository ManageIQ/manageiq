class AddGuidToMiqRegions < ActiveRecord::Migration
  def self.up
    add_column :miq_regions, :guid, :string, :limit => 36
  end

  def self.down
    remove_column :miq_regions, :guid
  end
end
