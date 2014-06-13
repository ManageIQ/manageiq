class CreateStoragesVms < ActiveRecord::Migration
  def self.up
    create_table :storages_vms, :id => false do |t|
      t.column  :storage_id,     :integer
      t.column  :vm_id,          :integer
    end

    add_index :storages_vms, [:vm_id, :storage_id], :unique => true
  end

  def self.down
    remove_index :storages_vms, [:vm_id, :storage_id]
    drop_table :storages_vms
  end
end
