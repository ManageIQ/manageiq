class AddIpmiAddressToHost < ActiveRecord::Migration
  def self.up
    add_column :hosts, :ipmi_address, :string
  end

  def self.down
    remove_column :hosts, :ipmi_address
  end
end
