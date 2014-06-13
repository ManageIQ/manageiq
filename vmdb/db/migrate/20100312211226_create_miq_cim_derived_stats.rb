class CreateMiqCimDerivedStats < ActiveRecord::Migration
  def self.up
    create_table :miq_cim_derived_stats do |t|
      t.column :statistic_time,       :datetime
      t.column :interval,           :integer
      t.column :k_bytes_read_per_sec,     :float
        t.column :read_ios_per_sec,       :float
        t.column :k_bytes_written_per_sec,    :float
        t.column :k_bytes_transferred_per_sec,  :float
        t.column :write_ios_per_sec,      :float
        t.column :write_hit_ios_per_sec,    :float
        t.column :read_hit_ios_per_sec,     :float
        t.column :total_ios_per_sec,      :float
      t.column :utilization,          :float
      t.column :response_time_sec,      :float
      t.column :queue_depth,          :float
      t.column :service_time_sec,       :float
      t.column :wait_time_sec,        :float
      t.column :avg_read_size,        :float
      t.column :avg_write_size,       :float
      t.column :pct_read,           :float
      t.column :pct_write,          :float
      t.column :pct_hit,            :float

      t.column :miq_cim_stat_id,        :integer
      t.column :position,           :integer
      t.timestamps
    end
    add_index :miq_cim_derived_stats, :miq_cim_stat_id
  end

  def self.down
    remove_index :miq_cim_derived_stats, :miq_cim_stat_id
    drop_table :miq_cim_derived_stats
  end
end
