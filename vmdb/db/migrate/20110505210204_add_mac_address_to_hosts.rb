class AddMacAddressToHosts < ActiveRecord::Migration
  def self.up
    add_column :hosts, :mac_address, :string
  end

  def self.down
    remove_column :hosts, :mac_address
  end
end
