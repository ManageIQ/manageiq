class OntapCreateMetricsRollupTables < ActiveRecord::Migration
  def up
    create_table :ontap_aggregate_metrics_rollups do |t|
      t.datetime  :statistic_time
      t.string    :rollup_type
      t.bigint    :interval

      t.float     :total_transfers
      t.float     :total_transfers_min
      t.float     :total_transfers_max

      t.float     :user_reads
      t.float     :user_reads_min
      t.float     :user_reads_max
      t.float     :user_writes
      t.float     :user_writes_min
      t.float     :user_writes_max
      t.float     :cp_reads
      t.float     :cp_reads_min
      t.float     :cp_reads_max
      t.float     :user_read_blocks
      t.float     :user_read_blocks_min
      t.float     :user_read_blocks_max
      t.float     :user_write_blocks
      t.float     :user_write_blocks_min
      t.float     :user_write_blocks_max
      t.float     :cp_read_blocks
      t.float     :cp_read_blocks_min
      t.float     :cp_read_blocks_max

      t.text      :base_counters
      t.text      :counter_info

      t.bigint    :miq_storage_metric_id
      t.bigint    :time_profile_id
      t.integer   :position
      t.timestamps
    end
    add_index :ontap_aggregate_metrics_rollups, :miq_storage_metric_id
    add_index :ontap_aggregate_metrics_rollups, :time_profile_id

    create_table :ontap_disk_metrics_rollups do |t|
      t.datetime  :statistic_time
      t.string    :rollup_type
      t.bigint    :interval

      t.float     :total_transfers
      t.float     :total_transfers_min
      t.float     :total_transfers_max
      t.float     :user_read_chain
      t.float     :user_read_chain_min
      t.float     :user_read_chain_max
      t.float     :user_reads
      t.float     :user_reads_min
      t.float     :user_reads_max
      t.float     :user_write_chain
      t.float     :user_write_chain_min
      t.float     :user_write_chain_max
      t.float     :user_writes
      t.float     :user_writes_min
      t.float     :user_writes_max
      t.float     :user_writes_in_skip_mask
      t.float     :user_writes_in_skip_mask_min
      t.float     :user_writes_in_skip_mask_max
      t.float     :user_skip_write_ios
      t.float     :user_skip_write_ios_min
      t.float     :user_skip_write_ios_max
      t.float     :cp_read_chain
      t.float     :cp_read_chain_min
      t.float     :cp_read_chain_max
      t.float     :cp_reads
      t.float     :cp_reads_min
      t.float     :cp_reads_max
      t.float     :guarenteed_read_chain
      t.float     :guarenteed_read_chain_min
      t.float     :guarenteed_read_chain_max
      t.float     :guarenteed_reads
      t.float     :guarenteed_reads_min
      t.float     :guarenteed_reads_max
      t.float     :guarenteed_write_chain
      t.float     :guarenteed_write_chain_min
      t.float     :guarenteed_write_chain_max
      t.float     :guarenteed_writes
      t.float     :guarenteed_writes_min
      t.float     :guarenteed_writes_max
      t.float     :user_read_latency
      t.float     :user_read_latency_min
      t.float     :user_read_latency_max
      t.float     :user_read_blocks
      t.float     :user_read_blocks_min
      t.float     :user_read_blocks_max
      t.float     :user_write_latency
      t.float     :user_write_latency_min
      t.float     :user_write_latency_max
      t.float     :user_write_blocks
      t.float     :user_write_blocks_min
      t.float     :user_write_blocks_max
      t.float     :skip_blocks
      t.float     :skip_blocks_min
      t.float     :skip_blocks_max
      t.float     :cp_read_latency
      t.float     :cp_read_latency_min
      t.float     :cp_read_latency_max
      t.float     :cp_read_blocks
      t.float     :cp_read_blocks_min
      t.float     :cp_read_blocks_max
      t.float     :guarenteed_read_latency
      t.float     :guarenteed_read_latency_min
      t.float     :guarenteed_read_latency_max
      t.float     :guarenteed_read_blocks
      t.float     :guarenteed_read_blocks_min
      t.float     :guarenteed_read_blocks_max
      t.float     :guarenteed_write_latency
      t.float     :guarenteed_write_latency_min
      t.float     :guarenteed_write_latency_max
      t.float     :guarenteed_write_blocks
      t.float     :guarenteed_write_blocks_min
      t.float     :guarenteed_write_blocks_max
      t.float     :disk_busy
      t.float     :disk_busy_min
      t.float     :disk_busy_max
      t.float     :io_pending
      t.float     :io_pending_min
      t.float     :io_pending_max
      t.float     :io_queued
      t.float     :io_queued_min
      t.float     :io_queued_max

      t.text      :base_counters
      t.text      :counter_info

      t.bigint    :miq_storage_metric_id
      t.bigint    :time_profile_id
      t.integer   :position
      t.timestamps
    end
    add_index :ontap_disk_metrics_rollups, :miq_storage_metric_id
    add_index :ontap_disk_metrics_rollups, :time_profile_id

    create_table :ontap_lun_metrics_rollups do |t|
      t.datetime  :statistic_time
      t.string    :rollup_type
      t.bigint    :interval

      t.float     :read_ops
      t.float     :read_ops_min
      t.float     :read_ops_max
      t.float     :write_ops
      t.float     :write_ops_min
      t.float     :write_ops_max
      t.float     :other_ops
      t.float     :other_ops_min
      t.float     :other_ops_max
      t.float     :total_ops
      t.float     :total_ops_min
      t.float     :total_ops_max
      t.float     :read_data
      t.float     :read_data_min
      t.float     :read_data_max
      t.float     :write_data
      t.float     :write_data_min
      t.float     :write_data_max
      t.float     :queue_full
      t.float     :queue_full_min
      t.float     :queue_full_max
      t.float     :avg_latency
      t.float     :avg_latency_min
      t.float     :avg_latency_max

      t.text      :base_counters
      t.text      :counter_info

      t.bigint    :miq_storage_metric_id
      t.bigint    :time_profile_id
      t.integer   :position
      t.timestamps
    end
    add_index :ontap_lun_metrics_rollups, :miq_storage_metric_id
    add_index :ontap_lun_metrics_rollups, :time_profile_id

    create_table :ontap_system_metrics_rollups do |t|
      t.datetime  :statistic_time
      t.string    :rollup_type
      t.bigint    :interval

      t.float     :cpu_busy
      t.float     :cpu_busy_min
      t.float     :cpu_busy_max
      t.float     :avg_processor_busy
      t.float     :avg_processor_busy_min
      t.float     :avg_processor_busy_max
      t.float     :total_processor_busy
      t.float     :total_processor_busy_min
      t.float     :total_processor_busy_max
      t.float     :read_ops
      t.float     :read_ops_min
      t.float     :read_ops_max
      t.float     :write_ops
      t.float     :write_ops_min
      t.float     :write_ops_max
      t.float     :total_ops
      t.float     :total_ops_min
      t.float     :total_ops_max
      t.float     :sys_read_latency
      t.float     :sys_read_latency_min
      t.float     :sys_read_latency_max
      t.float     :sys_write_latency
      t.float     :sys_write_latency_min
      t.float     :sys_write_latency_max
      t.float     :sys_avg_latency
      t.float     :sys_avg_latency_min
      t.float     :sys_avg_latency_max
      t.float     :nfs_ops
      t.float     :nfs_ops_min
      t.float     :nfs_ops_max
      t.float     :cifs_ops
      t.float     :cifs_ops_min
      t.float     :cifs_ops_max
      t.float     :http_ops
      t.float     :http_ops_min
      t.float     :http_ops_max
      t.float     :fcp_ops
      t.float     :fcp_ops_min
      t.float     :fcp_ops_max
      t.float     :iscsi_ops
      t.float     :iscsi_ops_min
      t.float     :iscsi_ops_max
      t.float     :net_data_recv
      t.float     :net_data_recv_min
      t.float     :net_data_recv_max
      t.float     :net_data_sent
      t.float     :net_data_sent_min
      t.float     :net_data_sent_max
      t.float     :disk_data_read
      t.float     :disk_data_read_min
      t.float     :disk_data_read_max
      t.float     :disk_data_written
      t.float     :disk_data_written_min
      t.float     :disk_data_written_max

      t.text      :base_counters
      t.text      :counter_info

      t.bigint    :miq_storage_metric_id
      t.bigint    :time_profile_id
      t.integer   :position
      t.timestamps
    end
    add_index :ontap_system_metrics_rollups, :miq_storage_metric_id
    add_index :ontap_system_metrics_rollups, :time_profile_id

    create_table :ontap_volume_metrics_rollups do |t|
      t.datetime  :statistic_time
      t.string    :rollup_type
      t.bigint    :interval

      t.float     :avg_latency
      t.float     :avg_latency_min
      t.float     :avg_latency_max
      t.float     :total_ops
      t.float     :total_ops_min
      t.float     :total_ops_max
      t.float     :read_data
      t.float     :read_data_min
      t.float     :read_data_max
      t.float     :read_latency
      t.float     :read_latency_min
      t.float     :read_latency_max
      t.float     :read_ops
      t.float     :read_ops_min
      t.float     :read_ops_max
      t.float     :write_data
      t.float     :write_data_min
      t.float     :write_data_max
      t.float     :write_latency
      t.float     :write_latency_min
      t.float     :write_latency_max
      t.float     :write_ops
      t.float     :write_ops_min
      t.float     :write_ops_max
      t.float     :other_latency
      t.float     :other_latency_min
      t.float     :other_latency_max
      t.float     :other_ops
      t.float     :other_ops_min
      t.float     :other_ops_max
      t.float     :nfs_read_data
      t.float     :nfs_read_data_min
      t.float     :nfs_read_data_max
      t.float     :nfs_read_latency
      t.float     :nfs_read_latency_min
      t.float     :nfs_read_latency_max
      t.float     :nfs_read_ops
      t.float     :nfs_read_ops_min
      t.float     :nfs_read_ops_max
      t.float     :nfs_write_data
      t.float     :nfs_write_data_min
      t.float     :nfs_write_data_max
      t.float     :nfs_write_latency
      t.float     :nfs_write_latency_min
      t.float     :nfs_write_latency_max
      t.float     :nfs_write_ops
      t.float     :nfs_write_ops_min
      t.float     :nfs_write_ops_max
      t.float     :nfs_other_latency
      t.float     :nfs_other_latency_min
      t.float     :nfs_other_latency_max
      t.float     :nfs_other_ops
      t.float     :nfs_other_ops_min
      t.float     :nfs_other_ops_max
      t.float     :cifs_read_data
      t.float     :cifs_read_data_min
      t.float     :cifs_read_data_max
      t.float     :cifs_read_latency
      t.float     :cifs_read_latency_min
      t.float     :cifs_read_latency_max
      t.float     :cifs_read_ops
      t.float     :cifs_read_ops_min
      t.float     :cifs_read_ops_max
      t.float     :cifs_write_data
      t.float     :cifs_write_data_min
      t.float     :cifs_write_data_max
      t.float     :cifs_write_latency
      t.float     :cifs_write_latency_min
      t.float     :cifs_write_latency_max
      t.float     :cifs_write_ops
      t.float     :cifs_write_ops_min
      t.float     :cifs_write_ops_max
      t.float     :cifs_other_latency
      t.float     :cifs_other_latency_min
      t.float     :cifs_other_latency_max
      t.float     :cifs_other_ops
      t.float     :cifs_other_ops_min
      t.float     :cifs_other_ops_max
      t.float     :san_read_data
      t.float     :san_read_data_min
      t.float     :san_read_data_max
      t.float     :san_read_latency
      t.float     :san_read_latency_min
      t.float     :san_read_latency_max
      t.float     :san_read_ops
      t.float     :san_read_ops_min
      t.float     :san_read_ops_max
      t.float     :san_write_data
      t.float     :san_write_data_min
      t.float     :san_write_data_max
      t.float     :san_write_latency
      t.float     :san_write_latency_min
      t.float     :san_write_latency_max
      t.float     :san_write_ops
      t.float     :san_write_ops_min
      t.float     :san_write_ops_max
      t.float     :san_other_latency
      t.float     :san_other_latency_min
      t.float     :san_other_latency_max
      t.float     :san_other_ops
      t.float     :san_other_ops_min
      t.float     :san_other_ops_max

      t.text      :base_counters
      t.text      :counter_info

      t.bigint    :miq_storage_metric_id
      t.bigint    :time_profile_id
      t.integer   :position
      t.timestamps
    end
    add_index :ontap_volume_metrics_rollups, :miq_storage_metric_id
    add_index :ontap_volume_metrics_rollups, :time_profile_id
  end

  def down
    remove_index  :ontap_aggregate_metrics_rollups, :miq_storage_metric_id
    remove_index  :ontap_aggregate_metrics_rollups, :time_profile_id
    drop_table    :ontap_aggregate_metrics_rollups

    remove_index  :ontap_disk_metrics_rollups, :miq_storage_metric_id
    remove_index  :ontap_disk_metrics_rollups, :time_profile_id
    drop_table    :ontap_disk_metrics_rollups

    remove_index  :ontap_lun_metrics_rollups, :miq_storage_metric_id
    remove_index  :ontap_lun_metrics_rollups, :time_profile_id
    drop_table    :ontap_lun_metrics_rollups

    remove_index  :ontap_system_metrics_rollups, :miq_storage_metric_id
    remove_index  :ontap_system_metrics_rollups, :time_profile_id
    drop_table    :ontap_system_metrics_rollups

    remove_index  :ontap_volume_metrics_rollups, :miq_storage_metric_id
    remove_index  :ontap_volume_metrics_rollups, :time_profile_id
    drop_table    :ontap_volume_metrics_rollups
  end
end
