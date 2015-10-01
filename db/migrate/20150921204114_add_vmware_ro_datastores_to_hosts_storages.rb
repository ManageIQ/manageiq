class AddVmwareRoDatastoresToHostsStorages < ActiveRecord::Migration
  def change
    add_column :hosts_storages, :read_only, :boolean
    add_column :hosts_storages, :id, :primary_key
  end
end
