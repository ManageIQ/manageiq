class RenamePathColumnInVmdbDatabases < ActiveRecord::Migration
  def change
    rename_column :vmdb_databases, :path, :data_directory
  end
end
