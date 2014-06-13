class CorrectColumnsInVmdbDatabaseMetrics < ActiveRecord::Migration
  def up
    rename_column :vmdb_database_metrics, :processes_running, :running_processes

    remove_column :vmdb_database_metrics, :disk_size
    add_column    :vmdb_database_metrics, :disk_total_bytes,  :bigint
    remove_column :vmdb_database_metrics, :allocated_size
    add_column    :vmdb_database_metrics, :disk_free_bytes,   :bigint
    remove_column :vmdb_database_metrics, :used_size
    add_column    :vmdb_database_metrics, :disk_used_bytes,   :bigint

    add_column    :vmdb_database_metrics, :disk_total_inodes, :bigint
    add_column    :vmdb_database_metrics, :disk_used_inodes,  :bigint
    add_column    :vmdb_database_metrics, :disk_free_inodes,  :bigint
  end

  def down
    rename_column :vmdb_database_metrics, :running_processes, :processes_running

    remove_column :vmdb_database_metrics, :disk_total_bytes
    add_column    :vmdb_database_metrics, :disk_size,        :float
    remove_column :vmdb_database_metrics, :disk_free_bytes
    add_column    :vmdb_database_metrics, :allocated_size,   :float
    remove_column :vmdb_database_metrics, :disk_used_bytes
    add_column    :vmdb_database_metrics, :used_size,        :float

    remove_column :vmdb_database_metrics, :disk_total_inodes
    remove_column :vmdb_database_metrics, :disk_used_inodes
    remove_column :vmdb_database_metrics, :disk_free_inodes
  end
end
