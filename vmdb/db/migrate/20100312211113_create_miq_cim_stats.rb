class CreateMiqCimStats < ActiveRecord::Migration
  def self.up
    create_table :miq_cim_stats do |t|
      t.column :stat_obj, :text
      t.timestamps
    end
  end

  def self.down
    drop_table :miq_cim_stats
  end
end
