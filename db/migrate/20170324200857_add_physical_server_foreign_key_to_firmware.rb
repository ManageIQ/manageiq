class AddPhysicalServerForeignKeyToFirmware < ActiveRecord::Migration[5.0]
  def change
    add_column :firmwares, :ph_server_uuid, :string
  end
end
