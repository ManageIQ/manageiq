require Rails.root.join('lib/migration_helper')

class SplitAndRenameVimPerformancesToMetricsOnSqlserver < ActiveRecord::Migration
  extend MigrationHelper

  def self.up
    self.send("up_for_#{connection.adapter_name.downcase}")
  end

  def self.down
    self.send("down_for_#{connection.adapter_name.downcase}")
  end

  def self.up_for_sqlserver
    create_performances_table :metrics
    copy_data :vim_performances, :metrics, :conditions => {:capture_interval_name => "realtime"}
    add_performances_indexes :metrics

    create_performances_table :metric_rollups
    copy_data :vim_performances, :metric_rollups, :conditions => ["capture_interval_name != ?", "realtime"]
    add_performances_indexes :metric_rollups

    drop_table :vim_performances
  end

  def self.down_for_sqlserver
    create_performances_table :vim_performances
    add_performances_indexes :vim_performances, :timestamp

    drop_table :metrics
    drop_table :metric_rollups
  end

  def self.up_for_postgresql
    drop_inheritance_trigger :vim_performances
    drop_trigger :metrics,        :metrics_inheritance
    drop_trigger :metric_rollups, :metric_rollups_inheritance

    drop_table_inheritance :metrics,        :vim_performances
    drop_table_inheritance :metric_rollups, :vim_performances

    add_metrics_inheritance_trigger
    add_metric_rollups_inheritance_trigger

    drop_table :vim_performances

    max_id = connection.select_value("SELECT MAX(id) FROM metrics")
    connection.set_pk_sequence! :metrics, max_id.to_i + 1 unless max_id.nil?

    max_id = connection.select_value("SELECT MAX(id) FROM metric_rollups")
    connection.set_pk_sequence! :metric_rollups, max_id.to_i + 1 unless max_id.nil?
  end

  def self.down_for_postgresql
    create_performances_table :vim_performances

    drop_inheritance_trigger :metrics
    drop_inheritance_trigger :metric_rollups

    add_table_inheritance :metrics,        :vim_performances, :conditions => ["capture_interval_name = ?",  "realtime"]
    add_table_inheritance :metric_rollups, :vim_performances, :conditions => ["capture_interval_name != ?", "realtime"]

    add_old_vim_performances_inheritance_trigger
    add_old_metrics_inheritance_trigger
    add_old_metric_rollups_inheritance_trigger
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

  def self.add_performances_indexes(table, ts_name = "ts")
    add_index table, [:resource_id, :resource_type, :capture_interval_name, :timestamp], :name => "index_#{table}_on_resource_and_#{ts_name}"
    add_index table, [:timestamp, :capture_interval_name], :name => "index_#{table}_on_#{ts_name}_and_capture_interval_name"
  end

  # NOTE: The reason we are doing the inheritance with a before that adds and
  # an after trigger that deletes is that otherwise returning NULL from the
  # before trigger causes INSERT INTO RETURNING to return nil.  ActiveRecord
  # uses this insert format to get the resultant id, so it ends up creating
  # an AR instance with a nil instead of an id.
  # See: https://gist.github.com/59067

  def self.add_metrics_inheritance_trigger
    # PostgreSQL specific
    add_trigger :before, :metrics, :metrics_inheritance_before, <<-EOSQL
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
      RETURN NEW;
    EOSQL

    add_trigger :after, :metrics, :metrics_inheritance_after, <<-EOSQL
      DELETE FROM ONLY metrics WHERE id = NEW.id;
      RETURN NEW;
    EOSQL
  end

  def self.add_metric_rollups_inheritance_trigger
    # PostgreSQL specific
    add_trigger :before, :metric_rollups, :metric_rollups_inheritance_before, <<-EOSQL
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
      RETURN NEW;
    EOSQL

    add_trigger :after, :metric_rollups, :metric_rollups_inheritance_after, <<-EOSQL
      DELETE FROM ONLY metric_rollups WHERE id = NEW.id;
      RETURN NEW;
    EOSQL
  end

  def self.drop_inheritance_trigger(table)
    drop_trigger table, "#{table}_inheritance_before"
    drop_trigger table, "#{table}_inheritance_after"
  end

  def self.add_old_vim_performances_inheritance_trigger
    # PostgreSQL specific
    add_trigger :before, :vim_performances, :vim_performances_inheritance_before, <<-EOSQL
      IF (NEW.capture_interval_name = 'realtime') THEN
        INSERT INTO metrics VALUES (NEW.*);
      ELSIF (NEW.capture_interval_name != 'realtime') THEN
        INSERT INTO metric_rollups VALUES (NEW.*);
      END IF;
      RETURN NEW;
    EOSQL

    add_trigger :after, :vim_performances, :vim_performances_inheritance_after, <<-EOSQL
      DELETE FROM ONLY metric_rollups WHERE id = NEW.id;
      RETURN NEW;
    EOSQL
  end

  def self.add_old_metrics_inheritance_trigger
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

  def self.add_old_metric_rollups_inheritance_trigger
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
