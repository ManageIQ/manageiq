class AddWebsocketToMiqServer < ActiveRecord::Migration[5.0]
  def change
    add_column :miq_servers, :has_active_websocket, :boolean
  end
end
