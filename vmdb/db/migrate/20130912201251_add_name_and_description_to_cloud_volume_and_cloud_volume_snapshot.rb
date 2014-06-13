class AddNameAndDescriptionToCloudVolumeAndCloudVolumeSnapshot < ActiveRecord::Migration
  def change
    add_column :cloud_volumes, :name, :string

    add_column :cloud_volume_snapshots, :name,        :string
    add_column :cloud_volume_snapshots, :description, :string
  end
end
