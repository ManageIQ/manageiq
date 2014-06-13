class CreateOntapAggregateDerivedStats < ActiveRecord::Migration
  def self.up
    create_table :ontap_aggregate_derived_stats do |t|
      t.column :statistic_time,       :datetime
      t.column :interval,             :integer

      t.column :total_transfers,      :float
      t.column :user_reads,           :float
      t.column :user_writes,          :float
      t.column :cp_reads,             :float
      t.column :user_read_blocks,     :float
      t.column :user_write_blocks,    :float
      t.column :cp_read_blocks,       :float

      t.column :miq_storage_stat_id,  :bigint
      t.column :position,             :integer
      t.timestamps
    end
    add_index :ontap_aggregate_derived_stats, :miq_storage_stat_id
  end

  def self.down
    remove_index :ontap_aggregate_derived_stats, :miq_storage_stat_id
    drop_table :ontap_aggregate_derived_stats
  end
end
