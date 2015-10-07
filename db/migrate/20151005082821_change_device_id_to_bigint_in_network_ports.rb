class ChangeDeviceIdToBigintInNetworkPorts < ActiveRecord::Migration
  def up
    change_column :network_ports, :device_id, :bigint
  end

  def down
    change_column :network_ports, :device_id, :integer
  end
end
