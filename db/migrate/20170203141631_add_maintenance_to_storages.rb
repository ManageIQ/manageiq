class AddMaintenanceToStorages < ActiveRecord::Migration[5.0]
  def change
    add_column :storages, :maintenance, :boolean
  end
end
