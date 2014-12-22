class UpdateCloudVolumeAndCloudVolumeSnapshot < ActiveRecord::Migration
  def up
    change_table :cloud_volumes do |t|
      t.remove     :vm_id
      t.remove     :device_name

      t.string     :status
      t.string     :description
      t.string     :volume_type
      t.boolean    :bootable
      t.datetime   :creation_time

      t.belongs_to :cloud_tenant, :type => :bigint
    end

    change_table :cloud_volume_snapshots do |t|
      t.string   :status
      t.datetime :creation_time
      t.integer  :size, :limit => 8

      t.belongs_to :cloud_tenant, :type => :bigint
    end
  end

  def down
    change_table :cloud_volumes do |t|
      t.belongs_to :vm,           :type => :bigint
      t.string     :device_name

      t.remove     :status
      t.remove     :description
      t.remove     :volume_type
      t.remove     :bootable
      t.remove     :creation_time

      t.remove     :cloud_tenant_id
    end

    change_table :cloud_volume_snapshots do |t|
      t.remove :status
      t.remove :creation_time
      t.remove :size

      t.remove :cloud_tenant_id
    end
  end
end
