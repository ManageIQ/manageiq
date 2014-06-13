require Rails.root.join('lib/migration_helper')

class CopyVimPerformancesDataToMetricsSubtablesOnPostgres < ActiveRecord::Migration
  # NOTE: This migration is reentrant so that any failures in the middle of the
  # data migration do not rollback the entire set, and so that not all of the
  # data is migrated in a single transaction.

  extend MigrationHelper

  self.no_transaction = true

  class VimPerformance < ActiveRecord::Base; end

  def self.up
    return unless postgresql? && connection.table_exists?("vim_performances")

    copy_vim_performances_data_to_metrics_subtables
    copy_vim_performances_data_to_metric_rollups_subtables

    add_indexes_to_metrics_subtables
    add_indexes_to_metric_rollups_subtables
  end

  def self.down
    return unless postgresql?

    (0..23).each { |n| drop_performances_indexes subtable_name(:metrics, n) }
    (1..12).each { |n| drop_performances_indexes subtable_name(:metric_rollups, n) }

    (0..23).each { |n| connection.execute("delete from #{subtable_name(:metrics, n)}")}
    (1..12).each { |n| connection.execute("delete from #{subtable_name(:metric_rollups, n)}")}
  end

  def self.copy_vim_performances_data_to_metrics_subtables
    (0..23).each do |n|
      copy_data :vim_performances, subtable_name(:metrics, n), :via => :bulk_copy, :conditions => ["capture_interval_name = ? AND EXTRACT(HOUR FROM timestamp) = ?", "realtime", n]
    end
  end

  def self.copy_vim_performances_data_to_metric_rollups_subtables
    (1..12).each do |n|
      copy_data :vim_performances, subtable_name(:metric_rollups, n), :via => :bulk_copy, :conditions => ["capture_interval_name != ? AND EXTRACT(MONTH FROM timestamp) = ?", "realtime", n]
    end
  end

  def self.add_indexes_to_metrics_subtables
    (0..23).each do |n|
      add_performances_indexes subtable_name(:metrics, n)
    end
  end

  def self.add_indexes_to_metric_rollups_subtables
    (1..12).each do |n|
      add_performances_indexes subtable_name(:metric_rollups, n)
    end
  end

  def self.subtable_name(inherit_from, index)
    "#{inherit_from}_#{index.to_s.rjust(2, '0')}"
  end

  def self.add_performances_indexes(table, ts_name = "ts")
    cols = [:resource_id, :resource_type, :capture_interval_name, :timestamp]
    name = "index_#{table}_on_resource_and_#{ts_name}"
    add_index(table, cols, :name => name) unless index_exists?(table, cols, :name => name)

    cols = [:timestamp, :capture_interval_name]
    name = "index_#{table}_on_#{ts_name}_and_capture_interval_name"
    add_index(table, cols, :name => name) unless index_exists?(table, cols, :name => name)
  end

  def self.drop_performances_indexes(table, ts_name = "ts")
    remove_index table, :name => "index_#{table}_on_resource_and_#{ts_name}"
    remove_index table, :name => "index_#{table}_on_#{ts_name}_and_capture_interval_name"
  end
end
