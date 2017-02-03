class AddMacAddressesToPhysicalServers < ActiveRecord::Migration[5.0]
  def change
    remove_column :physical_servers, :macAddress, :string
    add_column :physical_servers, :macAddresses, :string, array: true, default: []
  end
end
