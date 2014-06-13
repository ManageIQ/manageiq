require Rails.root.join('lib/migration_helper')

class RecreateVimPerformancesAsParentOfMetricsSubtablesOnPostgres < ActiveRecord::Migration
  extend MigrationHelper

  def self.up
    return unless postgresql? && connection.table_exists?("vim_performances")

    max_id = connection.select_value("SELECT MAX(id) FROM vim_performances")
    drop_table :vim_performances
    create_performances_table :vim_performances
    connection.set_pk_sequence! :vim_performances, max_id.to_i + 1 unless max_id.nil?

    add_table_inheritance :metrics,        :vim_performances, :conditions => ["capture_interval_name = ?",  "realtime"]
    add_table_inheritance :metric_rollups, :vim_performances, :conditions => ["capture_interval_name != ?", "realtime"]
    add_vim_performances_inheritance_trigger
  end

  def self.down
    return unless postgresql?

    drop_vim_performances_inheritance_trigger
    drop_table_inheritance :metrics,        :vim_performances
    drop_table_inheritance :metric_rollups, :vim_performances

    add_performances_indexes :vim_performances, :timestamp
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

  def self.add_vim_performances_inheritance_trigger
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
      DELETE FROM ONLY vim_performances WHERE id = NEW.id;
      RETURN NEW;
    EOSQL
  end

  def self.drop_vim_performances_inheritance_trigger
    drop_trigger :vim_performances, :vim_performances_inheritance_before
    drop_trigger :vim_performances, :vim_performances_inheritance_after
  end
end
