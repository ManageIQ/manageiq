class CreateCloudVolumeAndCloudVolumeSnapshot < ActiveRecord::Migration
  def change
    create_table :cloud_volumes do |t|
      t.string     :type
      t.string     :ems_ref
      t.string     :device_name
      t.bigint     :size
      t.belongs_to :ems
      t.belongs_to :availability_zone
      t.belongs_to :cloud_volume_snapshot
      t.belongs_to :vm
    end

    create_table :cloud_volume_snapshots do |t|
      t.string     :type
      t.string     :ems_ref
      t.belongs_to :ems
      t.belongs_to :cloud_volume
    end
  end
end
