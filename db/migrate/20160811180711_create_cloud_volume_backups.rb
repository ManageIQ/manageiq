class CreateCloudVolumeBackups < ActiveRecord::Migration[5.0]
  def change
    create_table :cloud_volume_backups do |t|
      t.bigint   :ems_id
      t.string   :type
      t.string   :name
      t.string   :description
      t.string   :ems_ref
      t.string   :status
      t.datetime :creation_time
      t.integer  :size
      t.integer  :object_count
      t.boolean  :is_incremental
      t.boolean  :has_dependent_backups
      t.bigint   :cloud_volume_id
      t.bigint   :availability_zone_id
    end

    add_index "cloud_volume_backups", ["ems_id"], :name => "index_cloud_volume_backups_on_ems_id"
  end
end
