class AddRootDeviceTypeToHardware < ActiveRecord::Migration
  def change
    add_column :hardwares, :root_device_type, :string
  end
end
