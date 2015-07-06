class ChangeTsIndexOnMetricsToAddResource < ActiveRecord::Migration
  def up
    self.send("up_#{connection.table_exists?("metrics_00") ? "with" : "without"}_subtables")
  end

  def down
    self.send("down_#{connection.table_exists?("metrics_00") ? "with" : "without"}_subtables")
  end

  #
  # State specific methods
  #

  def up_with_subtables
    (0..23).each { |n| add_resource_to_index subtable_name(:metrics, n) }
    (1..12).each { |n| add_resource_to_index subtable_name(:metric_rollups, n) }
  end

  def down_with_subtables
    (0..23).each { |n| remove_resource_from_index subtable_name(:metrics, n) }
    (1..12).each { |n| remove_resource_from_index subtable_name(:metric_rollups, n) }
  end

  def up_without_subtables
    add_resource_to_index :metrics
    add_resource_to_index :metric_rollups
  end

  def down_without_subtables
    remove_resource_from_index :metrics
    remove_resource_from_index :metric_rollups
  end

  #
  # Helper methods
  #

  def subtable_name(inherit_from, index)
    "#{inherit_from}_#{index.to_s.rjust(2, '0')}"
  end

  def add_resource_to_index(table)
    index_name = "index_#{table}_on_ts_and_capture_interval_name"
    remove_index table, :name => index_name
    add_index    table, [:timestamp, :capture_interval_name, :resource_id, :resource_type], :name => index_name
  end

  def remove_resource_from_index(table)
    index_name = "index_#{table}_on_ts_and_capture_interval_name"
    remove_index table, :name => index_name
    add_index    table, [:timestamp, :capture_interval_name], :name => index_name
  end
end
