require Rails.root.join('lib/migration_helper')

class CreateMetricsSubtablesOnPostgres < ActiveRecord::Migration
  extend MigrationHelper

  def self.up
    return unless postgresql? && connection.table_exists?("vim_performances")

    create_trigger_language

    create_performances_table :metrics
    (0..23).each do |n|
      s = subtable_name(:metrics, n)
      create_performances_table s
      add_table_inheritance     s, :metrics, :conditions => ["capture_interval_name = ? AND EXTRACT(HOUR FROM timestamp) = ?", "realtime", n]
    end
    add_metrics_inheritance_trigger

    create_performances_table :metric_rollups
    (1..12).each do |n|
      s = subtable_name(:metric_rollups, n)
      create_performances_table s
      add_table_inheritance     s, :metric_rollups, :conditions => ["capture_interval_name != ? AND EXTRACT(MONTH FROM timestamp) = ?", "realtime", n]
    end
    add_metric_rollups_inheritance_trigger
  end

  def self.down
    return unless postgresql?

    drop_trigger :metrics,        :metrics_inheritance
    drop_trigger :metric_rollups, :metric_rollups_inheritance

    (0..23).each { |n| drop_table subtable_name(:metrics, n) }
    (1..12).each { |n| drop_table subtable_name(:metric_rollups, n) }

    drop_table :metrics
    drop_table :metric_rollups
  end

  def self.subtable_name(inherit_from, index)
    "#{inherit_from}_#{index.to_s.rjust(2, '0')}"
  end

  def self.create_performances_table(table)
    create_table table do |t|
      t.datetime :timestamp
      t.integer  :capture_interval
      t.string   :resource_type
      t.bigint   :resource_id
      t.float    :cpu_usage_rate_average
      t.float    :cpu_usagemhz_rate_average
      t.float    :mem_usage_absolute_average
      t.float    :disk_usage_rate_average
      t.float    :net_usage_rate_average
      t.float    :sys_uptime_absolute_latest
      t.datetime :created_on
      t.float    :derived_cpu_available
      t.float    :derived_memory_available
      t.float    :derived_memory_used
      t.float    :derived_cpu_reserved
      t.float    :derived_memory_reserved
      t.integer  :derived_vm_count_on
      t.integer  :derived_host_count_on
      t.integer  :derived_vm_count_off
      t.integer  :derived_host_count_off
      t.float    :derived_storage_total
      t.float    :derived_storage_free
      t.string   :capture_interval_name
      t.text     :assoc_ids
      t.float    :cpu_ready_delta_summation
      t.float    :cpu_system_delta_summation
      t.float    :cpu_wait_delta_summation
      t.string   :resource_name
      t.float    :cpu_used_delta_summation
      t.text     :tag_names
      t.bigint   :parent_host_id
      t.bigint   :parent_ems_cluster_id
      t.bigint   :parent_storage_id
      t.bigint   :parent_ems_id
      t.float    :derived_storage_vm_count_registered
      t.float    :derived_storage_vm_count_unregistered
      t.float    :derived_storage_vm_count_unmanaged
      t.float    :derived_storage_used_registered
      t.float    :derived_storage_used_unregistered
      t.float    :derived_storage_used_unmanaged
      t.float    :derived_storage_snapshot_registered
      t.float    :derived_storage_snapshot_unregistered
      t.float    :derived_storage_snapshot_unmanaged
      t.float    :derived_storage_mem_registered
      t.float    :derived_storage_mem_unregistered
      t.float    :derived_storage_mem_unmanaged
      t.float    :derived_storage_disk_registered
      t.float    :derived_storage_disk_unregistered
      t.float    :derived_storage_disk_unmanaged
      t.float    :derived_storage_vm_count_managed
      t.float    :derived_storage_used_managed
      t.float    :derived_storage_snapshot_managed
      t.float    :derived_storage_mem_managed
      t.float    :derived_storage_disk_managed
      t.text     :min_max
      t.integer  :intervals_in_rollup
      t.float    :mem_vmmemctl_absolute_average
      t.float    :mem_vmmemctltarget_absolute_average
      t.float    :mem_swapin_absolute_average
      t.float    :mem_swapout_absolute_average
      t.float    :mem_swapped_absolute_average
      t.float    :mem_swaptarget_absolute_average
      t.float    :disk_devicelatency_absolute_average
      t.float    :disk_kernellatency_absolute_average
      t.float    :disk_queuelatency_absolute_average
      t.float    :derived_vm_used_disk_storage
      t.float    :derived_vm_allocated_disk_storage
      t.float    :derived_vm_numvcpus
      t.bigint   :time_profile_id
    end
  end

  def self.create_trigger_language
    say_with_time("create_trigger_language") do
      language_name = "plpgsql"

      count = connection.select_value <<-EOSQL, 'Query Language'
        SELECT COUNT(*) FROM pg_language WHERE lanname = '#{language_name}';
      EOSQL

      if count.to_i == 0
        connection.execute <<-EOSQL, 'Create language'
          CREATE LANGUAGE #{language_name};
        EOSQL
      end
    end
  end

  def self.add_metrics_inheritance_trigger
    # PostgreSQL specific
    add_trigger :before, :metrics, :metrics_inheritance, <<-EOSQL
      CASE EXTRACT(HOUR FROM NEW.timestamp)
        WHEN 0 THEN
          INSERT INTO metrics_00 VALUES (NEW.*);
        WHEN 1 THEN
          INSERT INTO metrics_01 VALUES (NEW.*);
        WHEN 2 THEN
          INSERT INTO metrics_02 VALUES (NEW.*);
        WHEN 3 THEN
          INSERT INTO metrics_03 VALUES (NEW.*);
        WHEN 4 THEN
          INSERT INTO metrics_04 VALUES (NEW.*);
        WHEN 5 THEN
          INSERT INTO metrics_05 VALUES (NEW.*);
        WHEN 6 THEN
          INSERT INTO metrics_06 VALUES (NEW.*);
        WHEN 7 THEN
          INSERT INTO metrics_07 VALUES (NEW.*);
        WHEN 8 THEN
          INSERT INTO metrics_08 VALUES (NEW.*);
        WHEN 9 THEN
          INSERT INTO metrics_09 VALUES (NEW.*);
        WHEN 10 THEN
          INSERT INTO metrics_10 VALUES (NEW.*);
        WHEN 11 THEN
          INSERT INTO metrics_11 VALUES (NEW.*);
        WHEN 12 THEN
          INSERT INTO metrics_12 VALUES (NEW.*);
        WHEN 13 THEN
          INSERT INTO metrics_13 VALUES (NEW.*);
        WHEN 14 THEN
          INSERT INTO metrics_14 VALUES (NEW.*);
        WHEN 15 THEN
          INSERT INTO metrics_15 VALUES (NEW.*);
        WHEN 16 THEN
          INSERT INTO metrics_16 VALUES (NEW.*);
        WHEN 17 THEN
          INSERT INTO metrics_17 VALUES (NEW.*);
        WHEN 18 THEN
          INSERT INTO metrics_18 VALUES (NEW.*);
        WHEN 19 THEN
          INSERT INTO metrics_19 VALUES (NEW.*);
        WHEN 20 THEN
          INSERT INTO metrics_20 VALUES (NEW.*);
        WHEN 21 THEN
          INSERT INTO metrics_21 VALUES (NEW.*);
        WHEN 22 THEN
          INSERT INTO metrics_22 VALUES (NEW.*);
        WHEN 23 THEN
          INSERT INTO metrics_23 VALUES (NEW.*);
      END CASE;
      RETURN NULL;
    EOSQL
  end

  def self.add_metric_rollups_inheritance_trigger
    # PostgreSQL specific
    add_trigger :before, :metric_rollups, :metric_rollups_inheritance, <<-EOSQL
      CASE EXTRACT(MONTH FROM NEW.timestamp)
        WHEN 1 THEN
          INSERT INTO metric_rollups_01 VALUES (NEW.*);
        WHEN 2 THEN
          INSERT INTO metric_rollups_02 VALUES (NEW.*);
        WHEN 3 THEN
          INSERT INTO metric_rollups_03 VALUES (NEW.*);
        WHEN 4 THEN
          INSERT INTO metric_rollups_04 VALUES (NEW.*);
        WHEN 5 THEN
          INSERT INTO metric_rollups_05 VALUES (NEW.*);
        WHEN 6 THEN
          INSERT INTO metric_rollups_06 VALUES (NEW.*);
        WHEN 7 THEN
          INSERT INTO metric_rollups_07 VALUES (NEW.*);
        WHEN 8 THEN
          INSERT INTO metric_rollups_08 VALUES (NEW.*);
        WHEN 9 THEN
          INSERT INTO metric_rollups_09 VALUES (NEW.*);
        WHEN 10 THEN
          INSERT INTO metric_rollups_10 VALUES (NEW.*);
        WHEN 11 THEN
          INSERT INTO metric_rollups_11 VALUES (NEW.*);
        WHEN 12 THEN
          INSERT INTO metric_rollups_12 VALUES (NEW.*);
      END CASE;
      RETURN NULL;
    EOSQL
  end
end
