class RemoveCimOntapStorageTables < ActiveRecord::Migration[5.0]
  def up
    drop_table :miq_cim_associations
    drop_table :miq_cim_derived_metrics
    drop_table :miq_cim_instances
    drop_table :miq_storage_metrics
    drop_table :ontap_aggregate_derived_metrics
    drop_table :ontap_aggregate_metrics_rollups
    drop_table :ontap_disk_derived_metrics
    drop_table :ontap_disk_metrics_rollups
    drop_table :ontap_lun_derived_metrics
    drop_table :ontap_lun_metrics_rollups
    drop_table :ontap_system_derived_metrics
    drop_table :ontap_system_metrics_rollups
    drop_table :ontap_volume_derived_metrics
    drop_table :ontap_volume_metrics_rollups
    drop_table :storage_managers
    drop_table :storage_metrics_metadata
  end

  def down
    create_table :miq_cim_associations do |t|
      t.string  :assoc_class
      t.string  :result_class
      t.string  :role
      t.string  :result_role
      t.string  :obj_name
      t.string  :result_obj_name
      t.bigint  :miq_cim_instance_id
      t.bigint  :result_instance_id
      t.integer :status
      t.bigint  :zone_id
      t.index   [:miq_cim_instance_id, :assoc_class, :role, :result_role], :name => "index_on_miq_cim_associations_for_gen_query"
      t.index   :miq_cim_instance_id, :name => "index_miq_cim_associations_on_miq_cim_instance_id"
      t.index   [:obj_name, :result_obj_name, :assoc_class], :name => "index_on_miq_cim_associations_for_point_to_point"
      t.index   :result_instance_id, :name => "index_miq_cim_associations_on_result_instance_id"
    end

    create_table :miq_cim_derived_metrics do |t|
      t.datetime :statistic_time
      t.integer  :interval
      t.float    :k_bytes_read_per_sec
      t.float    :read_ios_per_sec
      t.float    :k_bytes_written_per_sec
      t.float    :k_bytes_transferred_per_sec
      t.float    :write_ios_per_sec
      t.float    :write_hit_ios_per_sec
      t.float    :read_hit_ios_per_sec
      t.float    :total_ios_per_sec
      t.float    :utilization
      t.float    :response_time_sec
      t.float    :queue_depth
      t.float    :service_time_sec
      t.float    :wait_time_sec
      t.float    :avg_read_size
      t.float    :avg_write_size
      t.float    :pct_read
      t.float    :pct_write
      t.float    :pct_hit
      t.bigint   :miq_storage_metric_id
      t.datetime :created_at,                  :null => false
      t.datetime :updated_at,                  :null => false
      t.index    :miq_storage_metric_id, :name => "index_miq_cim_derived_metrics_on_miq_storage_metric_id"
    end

    create_table :miq_cim_instances do |t|
      t.string   :class_name
      t.string   :class_hier,             :limit => 1024
      t.string   :namespace
      t.string   :obj_name_str
      t.text     :obj_name
      t.text     :obj
      t.integer  :last_update_status
      t.boolean  :is_top_managed_element
      t.bigint   :top_managed_element_id
      t.bigint   :agent_top_id
      t.bigint   :agent_id
      t.bigint   :metric_id
      t.bigint   :metric_top_id
      t.datetime :created_at,                          :null => false
      t.datetime :updated_at,                          :null => false
      t.bigint   :vmdb_obj_id
      t.string   :vmdb_obj_type
      t.bigint   :zone_id
      t.string   :source
      t.string   :type
      t.text     :type_spec_obj
      t.index    :agent_id, :name => "index_miq_cim_instances_on_agent_id"
      t.index    :agent_top_id, :name => "index_miq_cim_instances_on_agent_top_id"
      t.index    :metric_id, :name => "index_miq_cim_instances_on_metric_id"
      t.index    :metric_top_id, :name => "index_miq_cim_instances_on_metric_top_id"
      t.index    :obj_name_str, :name => "index_miq_cim_instances_on_obj_name_str", :unique => true
      t.index    :top_managed_element_id, :name => "index_miq_cim_instances_on_top_managed_element_id"
      t.index    :type, :name => "index_miq_cim_instances_on_type"
    end

    create_table :miq_storage_metrics do |t|
      t.text     :metric_obj
      t.datetime :created_at, :null => false
      t.datetime :updated_at, :null => false
      t.string   :type
    end

    create_table :ontap_aggregate_derived_metrics do |t|
      t.datetime :statistic_time
      t.integer  :interval
      t.float    :total_transfers
      t.float    :user_reads
      t.float    :user_writes
      t.float    :cp_reads
      t.float    :user_read_blocks
      t.float    :user_write_blocks
      t.float    :cp_read_blocks
      t.bigint   :miq_storage_metric_id
      t.datetime :created_at,                  :null => false
      t.datetime :updated_at,                  :null => false
      t.text     :base_counters
      t.bigint   :miq_cim_instance_id
      t.bigint   :storage_metrics_metadata_id
      t.index    :miq_cim_instance_id, :name => "index_ontap_aggregate_derived_metrics_on_miq_cim_instance_id"
      t.index    :miq_storage_metric_id, :name => "index_ontap_aggregate_derived_metrics_on_miq_storage_metric_id"
      t.index    :storage_metrics_metadata_id, :name => "index_ontap_aggregate_derived_metrics_on_smm_id"
    end

    create_table :ontap_aggregate_metrics_rollups do |t|
      t.datetime :statistic_time
      t.string   :rollup_type
      t.bigint   :interval
      t.float    :total_transfers
      t.float    :total_transfers_min
      t.float    :total_transfers_max
      t.float    :user_reads
      t.float    :user_reads_min
      t.float    :user_reads_max
      t.float    :user_writes
      t.float    :user_writes_min
      t.float    :user_writes_max
      t.float    :cp_reads
      t.float    :cp_reads_min
      t.float    :cp_reads_max
      t.float    :user_read_blocks
      t.float    :user_read_blocks_min
      t.float    :user_read_blocks_max
      t.float    :user_write_blocks
      t.float    :user_write_blocks_min
      t.float    :user_write_blocks_max
      t.float    :cp_read_blocks
      t.float    :cp_read_blocks_min
      t.float    :cp_read_blocks_max
      t.text     :base_counters
      t.bigint   :miq_storage_metric_id
      t.bigint   :time_profile_id
      t.datetime :created_at,                  :null => false
      t.datetime :updated_at,                  :null => false
      t.bigint   :miq_cim_instance_id
      t.bigint   :storage_metrics_metadata_id
      t.index    :miq_cim_instance_id, :name => "index_ontap_aggregate_metrics_rollups_on_miq_cim_instance_id"
      t.index    :miq_storage_metric_id, :name => "index_ontap_aggregate_metrics_rollups_on_miq_storage_metric_id"
      t.index    :storage_metrics_metadata_id, :name => "index_ontap_aggregate_metrics_rollups_on_smm_id"
      t.index    :time_profile_id, :name => "index_ontap_aggregate_metrics_rollups_on_time_profile_id"
    end

    create_table :ontap_disk_derived_metrics do |t|
      t.datetime :statistic_time
      t.integer  :interval
      t.float    :total_transfers
      t.float    :user_read_chain
      t.float    :user_reads
      t.float    :user_write_chain
      t.float    :user_writes
      t.float    :user_writes_in_skip_mask
      t.float    :user_skip_write_ios
      t.float    :cp_read_chain
      t.float    :cp_reads
      t.float    :guarenteed_read_chain
      t.float    :guarenteed_reads
      t.float    :guarenteed_write_chain
      t.float    :guarenteed_writes
      t.float    :user_read_latency
      t.float    :user_read_blocks
      t.float    :user_write_latency
      t.float    :user_write_blocks
      t.float    :skip_blocks
      t.float    :cp_read_latency
      t.float    :cp_read_blocks
      t.float    :guarenteed_read_latency
      t.float    :guarenteed_read_blocks
      t.float    :guarenteed_write_latency
      t.float    :guarenteed_write_blocks
      t.float    :disk_busy
      t.float    :io_pending
      t.float    :io_queued
      t.bigint   :miq_storage_metric_id
      t.datetime :created_at,                  :null => false
      t.datetime :updated_at,                  :null => false
      t.text     :base_counters
      t.bigint   :miq_cim_instance_id
      t.bigint   :storage_metrics_metadata_id
      t.index    :miq_cim_instance_id, :name => "index_ontap_disk_derived_metrics_on_miq_cim_instance_id"
      t.index    :miq_storage_metric_id, :name => "index_ontap_disk_derived_metrics_on_miq_storage_metric_id"
      t.index    :storage_metrics_metadata_id, :name => "index_ontap_disk_derived_metrics_on_smm_id"
    end

    create_table :ontap_disk_metrics_rollups do |t|
      t.datetime :statistic_time
      t.string   :rollup_type
      t.bigint   :interval
      t.float    :total_transfers
      t.float    :total_transfers_min
      t.float    :total_transfers_max
      t.float    :user_read_chain
      t.float    :user_read_chain_min
      t.float    :user_read_chain_max
      t.float    :user_reads
      t.float    :user_reads_min
      t.float    :user_reads_max
      t.float    :user_write_chain
      t.float    :user_write_chain_min
      t.float    :user_write_chain_max
      t.float    :user_writes
      t.float    :user_writes_min
      t.float    :user_writes_max
      t.float    :user_writes_in_skip_mask
      t.float    :user_writes_in_skip_mask_min
      t.float    :user_writes_in_skip_mask_max
      t.float    :user_skip_write_ios
      t.float    :user_skip_write_ios_min
      t.float    :user_skip_write_ios_max
      t.float    :cp_read_chain
      t.float    :cp_read_chain_min
      t.float    :cp_read_chain_max
      t.float    :cp_reads
      t.float    :cp_reads_min
      t.float    :cp_reads_max
      t.float    :guarenteed_read_chain
      t.float    :guarenteed_read_chain_min
      t.float    :guarenteed_read_chain_max
      t.float    :guarenteed_reads
      t.float    :guarenteed_reads_min
      t.float    :guarenteed_reads_max
      t.float    :guarenteed_write_chain
      t.float    :guarenteed_write_chain_min
      t.float    :guarenteed_write_chain_max
      t.float    :guarenteed_writes
      t.float    :guarenteed_writes_min
      t.float    :guarenteed_writes_max
      t.float    :user_read_latency
      t.float    :user_read_latency_min
      t.float    :user_read_latency_max
      t.float    :user_read_blocks
      t.float    :user_read_blocks_min
      t.float    :user_read_blocks_max
      t.float    :user_write_latency
      t.float    :user_write_latency_min
      t.float    :user_write_latency_max
      t.float    :user_write_blocks
      t.float    :user_write_blocks_min
      t.float    :user_write_blocks_max
      t.float    :skip_blocks
      t.float    :skip_blocks_min
      t.float    :skip_blocks_max
      t.float    :cp_read_latency
      t.float    :cp_read_latency_min
      t.float    :cp_read_latency_max
      t.float    :cp_read_blocks
      t.float    :cp_read_blocks_min
      t.float    :cp_read_blocks_max
      t.float    :guarenteed_read_latency
      t.float    :guarenteed_read_latency_min
      t.float    :guarenteed_read_latency_max
      t.float    :guarenteed_read_blocks
      t.float    :guarenteed_read_blocks_min
      t.float    :guarenteed_read_blocks_max
      t.float    :guarenteed_write_latency
      t.float    :guarenteed_write_latency_min
      t.float    :guarenteed_write_latency_max
      t.float    :guarenteed_write_blocks
      t.float    :guarenteed_write_blocks_min
      t.float    :guarenteed_write_blocks_max
      t.float    :disk_busy
      t.float    :disk_busy_min
      t.float    :disk_busy_max
      t.float    :io_pending
      t.float    :io_pending_min
      t.float    :io_pending_max
      t.float    :io_queued
      t.float    :io_queued_min
      t.float    :io_queued_max
      t.text     :base_counters
      t.bigint   :miq_storage_metric_id
      t.bigint   :time_profile_id
      t.datetime :created_at,                   :null => false
      t.datetime :updated_at,                   :null => false
      t.bigint   :miq_cim_instance_id
      t.bigint   :storage_metrics_metadata_id
      t.index    :miq_cim_instance_id, :name => "index_ontap_disk_metrics_rollups_on_miq_cim_instance_id"
      t.index    :miq_storage_metric_id, :name => "index_ontap_disk_metrics_rollups_on_miq_storage_metric_id"
      t.index    :storage_metrics_metadata_id, :name => "index_ontap_disk_metrics_rollups_on_smm_id"
      t.index    :time_profile_id, :name => "index_ontap_disk_metrics_rollups_on_time_profile_id"
    end

    create_table :ontap_lun_derived_metrics do |t|
      t.datetime :statistic_time
      t.integer  :interval
      t.float    :read_ops
      t.float    :write_ops
      t.float    :other_ops
      t.float    :total_ops
      t.float    :read_data
      t.float    :write_data
      t.float    :queue_full
      t.float    :avg_latency
      t.bigint   :miq_storage_metric_id
      t.datetime :created_at,                  :null => false
      t.datetime :updated_at,                  :null => false
      t.text     :base_counters
      t.bigint   :miq_cim_instance_id
      t.bigint   :storage_metrics_metadata_id
      t.index    :miq_cim_instance_id, :name => "index_ontap_lun_derived_metrics_on_miq_cim_instance_id"
      t.index    :miq_storage_metric_id, :name => "index_ontap_lun_derived_metrics_on_miq_storage_metric_id"
      t.index    :storage_metrics_metadata_id, :name => "index_ontap_lun_derived_metrics_on_smm_id"
    end

    create_table :ontap_lun_metrics_rollups do |t|
      t.datetime :statistic_time
      t.string   :rollup_type
      t.bigint   :interval
      t.float    :read_ops
      t.float    :read_ops_min
      t.float    :read_ops_max
      t.float    :write_ops
      t.float    :write_ops_min
      t.float    :write_ops_max
      t.float    :other_ops
      t.float    :other_ops_min
      t.float    :other_ops_max
      t.float    :total_ops
      t.float    :total_ops_min
      t.float    :total_ops_max
      t.float    :read_data
      t.float    :read_data_min
      t.float    :read_data_max
      t.float    :write_data
      t.float    :write_data_min
      t.float    :write_data_max
      t.float    :queue_full
      t.float    :queue_full_min
      t.float    :queue_full_max
      t.float    :avg_latency
      t.float    :avg_latency_min
      t.float    :avg_latency_max
      t.text     :base_counters
      t.bigint   :miq_storage_metric_id
      t.bigint   :time_profile_id
      t.datetime :created_at,                  :null => false
      t.datetime :updated_at,                  :null => false
      t.bigint   :miq_cim_instance_id
      t.bigint   :storage_metrics_metadata_id
      t.index    :miq_cim_instance_id, :name => "index_ontap_lun_metrics_rollups_on_miq_cim_instance_id"
      t.index    :miq_storage_metric_id, :name => "index_ontap_lun_metrics_rollups_on_miq_storage_metric_id"
      t.index    :storage_metrics_metadata_id, :name => "index_ontap_lun_metrics_rollups_on_smm_id"
      t.index    :time_profile_id, :name => "index_ontap_lun_metrics_rollups_on_time_profile_id"
    end

    create_table :ontap_system_derived_metrics do |t|
      t.datetime :statistic_time
      t.integer  :interval
      t.float    :cpu_busy
      t.float    :avg_processor_busy
      t.float    :total_processor_busy
      t.float    :read_ops
      t.float    :write_ops
      t.float    :total_ops
      t.float    :sys_read_latency
      t.float    :sys_write_latency
      t.float    :sys_avg_latency
      t.float    :nfs_ops
      t.float    :cifs_ops
      t.float    :http_ops
      t.float    :fcp_ops
      t.float    :iscsi_ops
      t.float    :net_data_recv
      t.float    :net_data_sent
      t.float    :disk_data_read
      t.float    :disk_data_written
      t.bigint   :miq_storage_metric_id
      t.datetime :created_at,                  :null => false
      t.datetime :updated_at,                  :null => false
      t.text     :base_counters
      t.bigint   :miq_cim_instance_id
      t.bigint   :storage_metrics_metadata_id
      t.index    :miq_cim_instance_id, :name => "index_ontap_system_derived_metrics_on_miq_cim_instance_id"
      t.index    :miq_storage_metric_id, :name => "index_ontap_system_derived_metrics_on_miq_storage_metric_id"
      t.index    :storage_metrics_metadata_id, :name => "index_ontap_system_derived_metrics_on_smm_id"
    end

    create_table :ontap_system_metrics_rollups do |t|
      t.datetime :statistic_time
      t.string   :rollup_type
      t.bigint   :interval
      t.float    :cpu_busy
      t.float    :cpu_busy_min
      t.float    :cpu_busy_max
      t.float    :avg_processor_busy
      t.float    :avg_processor_busy_min
      t.float    :avg_processor_busy_max
      t.float    :total_processor_busy
      t.float    :total_processor_busy_min
      t.float    :total_processor_busy_max
      t.float    :read_ops
      t.float    :read_ops_min
      t.float    :read_ops_max
      t.float    :write_ops
      t.float    :write_ops_min
      t.float    :write_ops_max
      t.float    :total_ops
      t.float    :total_ops_min
      t.float    :total_ops_max
      t.float    :sys_read_latency
      t.float    :sys_read_latency_min
      t.float    :sys_read_latency_max
      t.float    :sys_write_latency
      t.float    :sys_write_latency_min
      t.float    :sys_write_latency_max
      t.float    :sys_avg_latency
      t.float    :sys_avg_latency_min
      t.float    :sys_avg_latency_max
      t.float    :nfs_ops
      t.float    :nfs_ops_min
      t.float    :nfs_ops_max
      t.float    :cifs_ops
      t.float    :cifs_ops_min
      t.float    :cifs_ops_max
      t.float    :http_ops
      t.float    :http_ops_min
      t.float    :http_ops_max
      t.float    :fcp_ops
      t.float    :fcp_ops_min
      t.float    :fcp_ops_max
      t.float    :iscsi_ops
      t.float    :iscsi_ops_min
      t.float    :iscsi_ops_max
      t.float    :net_data_recv
      t.float    :net_data_recv_min
      t.float    :net_data_recv_max
      t.float    :net_data_sent
      t.float    :net_data_sent_min
      t.float    :net_data_sent_max
      t.float    :disk_data_read
      t.float    :disk_data_read_min
      t.float    :disk_data_read_max
      t.float    :disk_data_written
      t.float    :disk_data_written_min
      t.float    :disk_data_written_max
      t.text     :base_counters
      t.bigint   :miq_storage_metric_id
      t.bigint   :time_profile_id
      t.datetime :created_at,                  :null => false
      t.datetime :updated_at,                  :null => false
      t.bigint   :miq_cim_instance_id
      t.bigint   :storage_metrics_metadata_id
      t.index    :miq_cim_instance_id, :name => "index_ontap_system_metrics_rollups_on_miq_cim_instance_id"
      t.index    :miq_storage_metric_id, :name => "index_ontap_system_metrics_rollups_on_miq_storage_metric_id"
      t.index    :storage_metrics_metadata_id, :name => "index_ontap_system_metrics_rollups_on_smm_id"
      t.index    :time_profile_id, :name => "index_ontap_system_metrics_rollups_on_time_profile_id"
    end

    create_table :ontap_volume_derived_metrics do |t|
      t.datetime :statistic_time
      t.integer  :interval
      t.float    :avg_latency
      t.float    :total_ops
      t.float    :read_data
      t.float    :read_latency
      t.float    :read_ops
      t.float    :write_data
      t.float    :write_latency
      t.float    :write_ops
      t.float    :other_latency
      t.float    :other_ops
      t.float    :nfs_read_data
      t.float    :nfs_read_latency
      t.float    :nfs_read_ops
      t.float    :nfs_write_data
      t.float    :nfs_write_latency
      t.float    :nfs_write_ops
      t.float    :nfs_other_latency
      t.float    :nfs_other_ops
      t.float    :cifs_read_data
      t.float    :cifs_read_latency
      t.float    :cifs_read_ops
      t.float    :cifs_write_data
      t.float    :cifs_write_latency
      t.float    :cifs_write_ops
      t.float    :cifs_other_latency
      t.float    :cifs_other_ops
      t.float    :san_read_data
      t.float    :san_read_latency
      t.float    :san_read_ops
      t.float    :san_write_data
      t.float    :san_write_latency
      t.float    :san_write_ops
      t.float    :san_other_latency
      t.float    :san_other_ops
      t.float    :queue_depth
      t.bigint   :miq_storage_metric_id
      t.datetime :created_at,                  :null => false
      t.datetime :updated_at,                  :null => false
      t.text     :base_counters
      t.bigint   :miq_cim_instance_id
      t.bigint   :storage_metrics_metadata_id
      t.index    :miq_cim_instance_id, :name => "index_ontap_volume_derived_metrics_on_miq_cim_instance_id"
      t.index    :miq_storage_metric_id, :name => "index_ontap_volume_derived_metrics_on_miq_storage_metric_id"
      t.index    :storage_metrics_metadata_id, :name => "index_ontap_volume_derived_metrics_on_smm_id"
    end

    create_table :ontap_volume_metrics_rollups do |t|
      t.datetime :statistic_time
      t.string   :rollup_type
      t.bigint   :interval
      t.float    :avg_latency
      t.float    :avg_latency_min
      t.float    :avg_latency_max
      t.float    :total_ops
      t.float    :total_ops_min
      t.float    :total_ops_max
      t.float    :read_data
      t.float    :read_data_min
      t.float    :read_data_max
      t.float    :read_latency
      t.float    :read_latency_min
      t.float    :read_latency_max
      t.float    :read_ops
      t.float    :read_ops_min
      t.float    :read_ops_max
      t.float    :write_data
      t.float    :write_data_min
      t.float    :write_data_max
      t.float    :write_latency
      t.float    :write_latency_min
      t.float    :write_latency_max
      t.float    :write_ops
      t.float    :write_ops_min
      t.float    :write_ops_max
      t.float    :other_latency
      t.float    :other_latency_min
      t.float    :other_latency_max
      t.float    :other_ops
      t.float    :other_ops_min
      t.float    :other_ops_max
      t.float    :nfs_read_data
      t.float    :nfs_read_data_min
      t.float    :nfs_read_data_max
      t.float    :nfs_read_latency
      t.float    :nfs_read_latency_min
      t.float    :nfs_read_latency_max
      t.float    :nfs_read_ops
      t.float    :nfs_read_ops_min
      t.float    :nfs_read_ops_max
      t.float    :nfs_write_data
      t.float    :nfs_write_data_min
      t.float    :nfs_write_data_max
      t.float    :nfs_write_latency
      t.float    :nfs_write_latency_min
      t.float    :nfs_write_latency_max
      t.float    :nfs_write_ops
      t.float    :nfs_write_ops_min
      t.float    :nfs_write_ops_max
      t.float    :nfs_other_latency
      t.float    :nfs_other_latency_min
      t.float    :nfs_other_latency_max
      t.float    :nfs_other_ops
      t.float    :nfs_other_ops_min
      t.float    :nfs_other_ops_max
      t.float    :cifs_read_data
      t.float    :cifs_read_data_min
      t.float    :cifs_read_data_max
      t.float    :cifs_read_latency
      t.float    :cifs_read_latency_min
      t.float    :cifs_read_latency_max
      t.float    :cifs_read_ops
      t.float    :cifs_read_ops_min
      t.float    :cifs_read_ops_max
      t.float    :cifs_write_data
      t.float    :cifs_write_data_min
      t.float    :cifs_write_data_max
      t.float    :cifs_write_latency
      t.float    :cifs_write_latency_min
      t.float    :cifs_write_latency_max
      t.float    :cifs_write_ops
      t.float    :cifs_write_ops_min
      t.float    :cifs_write_ops_max
      t.float    :cifs_other_latency
      t.float    :cifs_other_latency_min
      t.float    :cifs_other_latency_max
      t.float    :cifs_other_ops
      t.float    :cifs_other_ops_min
      t.float    :cifs_other_ops_max
      t.float    :san_read_data
      t.float    :san_read_data_min
      t.float    :san_read_data_max
      t.float    :san_read_latency
      t.float    :san_read_latency_min
      t.float    :san_read_latency_max
      t.float    :san_read_ops
      t.float    :san_read_ops_min
      t.float    :san_read_ops_max
      t.float    :san_write_data
      t.float    :san_write_data_min
      t.float    :san_write_data_max
      t.float    :san_write_latency
      t.float    :san_write_latency_min
      t.float    :san_write_latency_max
      t.float    :san_write_ops
      t.float    :san_write_ops_min
      t.float    :san_write_ops_max
      t.float    :san_other_latency
      t.float    :san_other_latency_min
      t.float    :san_other_latency_max
      t.float    :san_other_ops
      t.float    :san_other_ops_min
      t.float    :san_other_ops_max
      t.text     :base_counters
      t.bigint   :miq_storage_metric_id
      t.bigint   :time_profile_id
      t.datetime :created_at,                  :null => false
      t.datetime :updated_at,                  :null => false
      t.bigint   :miq_cim_instance_id
      t.bigint   :storage_metrics_metadata_id
      t.index    :miq_cim_instance_id, :name => "index_ontap_volume_metrics_rollups_on_miq_cim_instance_id"
      t.index    :miq_storage_metric_id, :name => "index_ontap_volume_metrics_rollups_on_miq_storage_metric_id"
      t.index    :storage_metrics_metadata_id, :name => "index_ontap_volume_metrics_rollups_on_smm_id"
      t.index    :time_profile_id, :name => "index_ontap_volume_metrics_rollups_on_time_profile_id"
    end

    create_table :storage_managers do |t|
      t.string   :ipaddress
      t.string   :agent_type
      t.integer  :last_update_status
      t.datetime :created_at,         :null => false
      t.datetime :updated_at,         :null => false
      t.bigint   :zone_id
      t.string   :name
      t.string   :hostname
      t.string   :port
      t.bigint   :parent_agent_id
      t.string   :vendor
      t.string   :version
      t.string   :type
      t.text     :type_spec_data
      t.index    :parent_agent_id, :name => "index_storage_managers_on_parent_agent_id"
      t.index    :zone_id, :name => "index_storage_managers_on_zone_id"
    end

    create_table :storage_metrics_metadata do |t|
      t.string   :type
      t.text     :counter_info
      t.datetime :created_at,   :null => false
      t.datetime :updated_at,   :null => false
    end
  end
end
