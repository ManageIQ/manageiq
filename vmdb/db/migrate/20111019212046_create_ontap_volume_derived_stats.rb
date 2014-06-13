class CreateOntapVolumeDerivedStats < ActiveRecord::Migration
  def self.up
    create_table :ontap_volume_derived_stats do |t|
      t.column :statistic_time,     :datetime
      t.column :interval,           :integer

      t.column :avg_latency,        :float
      t.column :total_ops,          :float
      t.column :read_data,          :float
      t.column :read_latency,       :float
      t.column :read_ops,           :float
      t.column :write_data,         :float
      t.column :write_latency,      :float
      t.column :write_ops,          :float
      t.column :other_latency,      :float
      t.column :other_ops,          :float

      t.column :nfs_read_data,      :float
      t.column :nfs_read_latency,   :float
      t.column :nfs_read_ops,       :float
      t.column :nfs_write_data,     :float
      t.column :nfs_write_latency,  :float
      t.column :nfs_write_ops,      :float
      t.column :nfs_other_latency,  :float
      t.column :nfs_other_ops,      :float

      t.column :cifs_read_data,     :float
      t.column :cifs_read_latency,  :float
      t.column :cifs_read_ops,      :float
      t.column :cifs_write_data,    :float
      t.column :cifs_write_latency, :float
      t.column :cifs_write_ops,     :float
      t.column :cifs_other_latency, :float
      t.column :cifs_other_ops,     :float

      t.column :san_read_data,      :float
      t.column :san_read_latency,   :float
      t.column :san_read_ops,       :float
      t.column :san_write_data,     :float
      t.column :san_write_latency,  :float
      t.column :san_write_ops,      :float
      t.column :san_other_latency,  :float
      t.column :san_other_ops,      :float

      t.column :queue_depth,        :float

      t.column :miq_cim_stat_id,    :bigint
      t.column :position,           :integer
      t.timestamps
    end
    add_index :ontap_volume_derived_stats, :miq_cim_stat_id
  end

  def self.down
    remove_index :ontap_volume_derived_stats, :miq_cim_stat_id
    drop_table :ontap_volume_derived_stats
  end
end
