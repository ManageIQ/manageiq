class CreateOntapSystemDerivedStats < ActiveRecord::Migration
  def self.up
    create_table :ontap_system_derived_stats do |t|
      t.column :statistic_time,         :datetime
      t.column :interval,               :integer

      t.column :cpu_busy,               :float
      t.column :avg_processor_busy,     :float
      t.column :avg_processor_busy,     :float
      t.column :total_processor_busy,   :float

      t.column :read_ops,               :float
      t.column :write_ops,              :float
      t.column :total_ops,              :float

      t.column :sys_read_latency,       :float
      t.column :sys_write_latency,      :float
      t.column :sys_avg_latency,        :float

      t.column :nfs_ops,                :float
      t.column :cifs_ops,               :float
      t.column :http_ops,               :float
      t.column :fcp_ops,                :float
      t.column :iscsi_ops,              :float

      t.column :net_data_recv,          :float
      t.column :net_data_sent,          :float

      t.column :disk_data_read,         :float
      t.column :disk_data_written,      :float

      t.column :miq_storage_stat_id,    :bigint
      t.column :position,               :integer
      t.timestamps
    end
    add_index :ontap_system_derived_stats, :miq_storage_stat_id
  end

  def self.down
    remove_index :ontap_system_derived_stats, :miq_storage_stat_id
    drop_table :ontap_system_derived_stats
  end
end
