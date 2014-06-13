class RemoveOwnerFromVms < ActiveRecord::Migration
  def self.up
    remove_column :vms, :owner
  end

  def self.down
    add_column    :vms, :owner, :text
  end
end
