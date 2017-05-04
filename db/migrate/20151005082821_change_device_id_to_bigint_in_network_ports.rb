class ChangeDeviceIdToBigintInNetworkPorts < ActiveRecord::Migration[4.2]
  def up
    change_column :network_ports, :device_id, :bigint
  end

  def down
    change_column :network_ports, :device_id, :integer
  end
end
