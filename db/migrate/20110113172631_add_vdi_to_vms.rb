class AddVdiToVms < ActiveRecord::Migration
  def self.up
    add_column    :vms, :vdi, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :vms, :vdi
  end
end
