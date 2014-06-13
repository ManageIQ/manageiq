class AddPriorRawMetricsToVmdbTablesAndVmdbIndexes < ActiveRecord::Migration
  def self.up
    add_column      :vmdb_tables,  :prior_raw_metrics,  :text

    add_column      :vmdb_indexes, :prior_raw_metrics,  :text
  end

  def self.down
    remove_column   :vmdb_tables,  :prior_raw_metrics

    remove_column   :vmdb_indexes, :prior_raw_metrics
  end
end
