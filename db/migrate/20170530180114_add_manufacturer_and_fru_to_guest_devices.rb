class AddManufacturerAndFruToGuestDevices < ActiveRecord::Migration[5.0]
  def change
    add_column :guest_devices, :manufacturer, :string
    add_column :guest_devices, :field_replaceable_unit, :string
    add_column :guest_devices, :parent_device_id, :bigint
    add_index :guest_devices, :parent_device_id, :name => "index_guest_devices_on_parent_device_id"
  end
end
