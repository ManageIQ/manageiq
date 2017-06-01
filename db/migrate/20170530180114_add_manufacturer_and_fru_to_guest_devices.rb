class AddManufacturerAndFruToGuestDevices < ActiveRecord::Migration[5.0]
  def change
    add_column :guest_devices, :manufacturer, :string
    add_column :guest_devices, :fru, :string
    add_column :guest_devices, :guest_device_id, :bigint
    add_index :guest_devices, :guest_device_id, :name => "index_guest_devices_on_guest_device_id"  
  end
end
