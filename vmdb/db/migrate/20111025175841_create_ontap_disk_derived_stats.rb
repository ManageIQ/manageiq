class CreateOntapDiskDerivedStats < ActiveRecord::Migration
  def self.up
    create_table :ontap_disk_derived_stats do |t|
      t.column :statistic_time,           :datetime
      t.column :interval,                 :integer

      t.column :total_transfers,          :float
      t.column :user_read_chain,          :float
      t.column :user_reads,               :float
      t.column :user_write_chain,         :float
      t.column :user_writes,              :float
      t.column :user_writes_in_skip_mask, :float
      t.column :user_skip_write_ios,      :float
      t.column :cp_read_chain,            :float
      t.column :cp_reads,                 :float
      t.column :guarenteed_read_chain,    :float
      t.column :guarenteed_reads,         :float
      t.column :guarenteed_write_chain,   :float
      t.column :guarenteed_writes,        :float
      t.column :user_read_latency,        :float
      t.column :user_read_blocks,         :float
      t.column :user_write_latency,       :float
      t.column :user_write_blocks,        :float
      t.column :skip_blocks,              :float
      t.column :cp_read_latency,          :float
      t.column :cp_read_blocks,           :float
      t.column :guarenteed_read_latency,  :float
      t.column :guarenteed_read_blocks,   :float
      t.column :guarenteed_write_latency, :float
      t.column :guarenteed_write_blocks,  :float
      t.column :disk_busy,                :float
      t.column :io_pending,               :float
      t.column :io_queued,                :float

      t.column :miq_storage_stat_id,      :bigint
      t.column :position,                 :integer
      t.timestamps
    end
    add_index :ontap_disk_derived_stats, :miq_storage_stat_id
  end

  def self.down
    remove_index :ontap_disk_derived_stats, :miq_storage_stat_id
    drop_table :ontap_disk_derived_stats
  end
end
