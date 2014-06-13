class AddMasterToStorages < ActiveRecord::Migration
  def change
    add_column :storages, :master, :boolean, :default => false
  end
end
