class CreateCloudVolumeAndCloudVolumeSnapshot < ActiveRecord::Migration
  def change
    create_table :cloud_volumes do |t|
      t.string     :type
      t.string     :ems_ref
      t.string     :device_name
      t.bigint     :size
      t.belongs_to :ems,                   :type => :bigint
      t.belongs_to :availability_zone,     :type => :bigint
      t.belongs_to :cloud_volume_snapshot, :type => :bigint
      t.belongs_to :vm,                    :type => :bigint
    end

    create_table :cloud_volume_snapshots do |t|
      t.string     :type
      t.string     :ems_ref
      t.belongs_to :ems,                   :type => :bigint
      t.belongs_to :cloud_volume,          :type => :bigint
    end
  end
end
