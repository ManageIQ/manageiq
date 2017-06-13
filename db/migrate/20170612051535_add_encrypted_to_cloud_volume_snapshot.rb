class AddEncryptedToCloudVolumeSnapshot < ActiveRecord::Migration[5.0]
  def change
    add_column :cloud_volume_snapshots, :encrypted, :boolean
  end
end
