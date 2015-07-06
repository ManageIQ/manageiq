class PluralizeColumnsOnVmdbMetrics < ActiveRecord::Migration
  def change
    rename_column :vmdb_metrics, :table_scan, :table_scans
    rename_column :vmdb_metrics, :index_scan, :index_scans
  end
end
