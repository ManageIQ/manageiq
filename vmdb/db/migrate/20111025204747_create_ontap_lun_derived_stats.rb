class CreateOntapLunDerivedStats < ActiveRecord::Migration
  def self.up
    create_table :ontap_lun_derived_stats do |t|
      t.column :statistic_time,       :datetime
      t.column :interval,             :integer

      t.column :read_ops,             :float
      t.column :write_ops,            :float
      t.column :other_ops,            :float
      t.column :total_ops,            :float
      t.column :read_data,            :float
      t.column :write_data,           :float
      t.column :queue_full,           :float
      t.column :avg_latency,          :float

      t.column :miq_storage_stat_id,  :bigint
      t.column :position,             :integer
      t.timestamps
    end
    add_index :ontap_lun_derived_stats, :miq_storage_stat_id
  end

  def self.down
    remove_index :ontap_lun_derived_stats, :miq_storage_stat_id
    drop_table :ontap_lun_derived_stats
  end
end
