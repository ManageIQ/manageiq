class AddCpuMemoryHotPlugToVms < ActiveRecord::Migration[5.0]
  def change
    add_column :vms, :cpu_hot_add_enabled,      :boolean
    add_column :vms, :cpu_hot_remove_enabled,   :boolean
    add_column :vms, :memory_hot_add_enabled,   :boolean
    add_column :vms, :memory_hot_add_limit,     :int
    add_column :vms, :memory_hot_add_increment, :int
  end
end
