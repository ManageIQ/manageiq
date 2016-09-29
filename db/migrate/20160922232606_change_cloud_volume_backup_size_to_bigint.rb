class ChangeCloudVolumeBackupSizeToBigint < ActiveRecord::Migration[5.0]
  def up
    change_column :cloud_volume_backups, :size, :bigint
  end

  def down
    change_column :cloud_volume_backups, :size, :integer
  end
end
