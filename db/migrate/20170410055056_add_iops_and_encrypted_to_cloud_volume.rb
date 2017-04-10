class AddIopsAndEncryptedToCloudVolume < ActiveRecord::Migration[5.0]
  def change
    add_column :cloud_volumes, :iops, :integer
    add_column :cloud_volumes, :encrypted, :boolean
  end
end
