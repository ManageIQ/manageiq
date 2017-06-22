class AddGuestDeviceIdToFirmwares < ActiveRecord::Migration[5.0]
  def change
    add_column :firmwares, :guest_device_id, :bigint
    add_index :firmwares, :guest_device_id, :name => "index_firmwares_on_guest_device_id"
  end
end
