class AddPropertiesToPhysicalServers < ActiveRecord::Migration[5.0]
  def change
    add_column :physical_servers, :hostname, :string
    add_column :physical_servers, :ipv4Addresses, :string, array: true, default: []
    add_column :physical_servers, :ipv6Addresses, :string, array: true, default: []
    add_column :physical_servers, :macAddress, :string
    add_column :physical_servers, :productName, :string
    add_column :physical_servers, :manufacturer, :string
    add_column :physical_servers, :machineType, :string
    add_column :physical_servers, :model, :string
    add_column :physical_servers, :serialNumber, :string
    add_column :physical_servers, :uuid, :string
    add_column :physical_servers, :FRU, :string
    add_column :physical_servers, :firmware_id, :bigint
  end
end
