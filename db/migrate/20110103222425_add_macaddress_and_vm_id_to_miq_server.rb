class AddMacaddressAndVmIdToMiqServer < ActiveRecord::Migration
  def self.up
    add_column :miq_servers, :mac_address, :string
    add_column :miq_servers, :vm_id,       :bigint
  end

  def self.down
    remove_column :miq_servers, :mac_address
    remove_column :miq_servers, :vm_id
  end
end
