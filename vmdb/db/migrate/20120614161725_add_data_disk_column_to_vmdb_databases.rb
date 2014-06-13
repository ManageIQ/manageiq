class AddDataDiskColumnToVmdbDatabases < ActiveRecord::Migration
  def change
    add_column :vmdb_databases, :data_disk, :string
  end
end
