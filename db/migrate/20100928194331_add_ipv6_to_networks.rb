class AddIpv6ToNetworks < ActiveRecord::Migration
  def self.up
    add_column :networks, :ipv6address, :string
  end

  def self.down
    remove_column :networks, :ipv6address
  end
end
