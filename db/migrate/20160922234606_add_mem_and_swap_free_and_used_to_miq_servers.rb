class AddMemAndSwapFreeAndUsedToMiqServers < ActiveRecord::Migration[5.0]
  def change
    add_column :miq_servers, :system_memory_free, :decimal, :precision => 20, :scale => 0
    add_column :miq_servers, :system_memory_used, :decimal, :precision => 20, :scale => 0
    add_column :miq_servers, :system_swap_free,   :decimal, :precision => 20, :scale => 0
    add_column :miq_servers, :system_swap_used,   :decimal, :precision => 20, :scale => 0
  end
end
