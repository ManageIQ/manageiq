class CreateDatabaseBackups < ActiveRecord::Migration
  def self.up
    create_table :database_backups do |t|
      t.string      :name
      t.timestamps
    end
  end

  def self.down
    drop_table :database_backups
  end
end
