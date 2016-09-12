class AddSourceToNetworkPorts < ActiveRecord::Migration[5.0]
  def change
    add_column :network_ports, :source, :string
  end
end
