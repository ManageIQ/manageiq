class AddMacAddressesToNetworks < ActiveRecord::Migration[5.0]
  def change
    add_column :networks, :mac_addresses, :string
  end
end
