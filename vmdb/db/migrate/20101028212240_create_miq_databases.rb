class CreateMiqDatabases < ActiveRecord::Migration
  def self.up
    create_table :miq_databases do |t|
      t.timestamps
      t.bigint    :miq_region_id
    end
    add_index :miq_databases, :miq_region_id
  end

  def self.down
    drop_table    :miq_databases
  end
end
