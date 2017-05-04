class AddRootDeviceTypeToHardware < ActiveRecord::Migration[4.2]
  def change
    add_column :hardwares, :root_device_type, :string
  end
end
