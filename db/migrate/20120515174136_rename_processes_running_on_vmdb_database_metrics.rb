class RenameProcessesRunningOnVmdbDatabaseMetrics < ActiveRecord::Migration
  def change
    rename_column :vmdb_database_metrics, :processses_running, :processes_running
  end
end
