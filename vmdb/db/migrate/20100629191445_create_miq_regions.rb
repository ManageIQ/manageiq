class CreateMiqRegions < ActiveRecord::Migration
  def self.up
    create_table :miq_regions do |t|
      t.integer :region
      t.text    :reserved
      t.timestamps
    end
  end

  def self.down
    drop_table :miq_regions
  end
end
