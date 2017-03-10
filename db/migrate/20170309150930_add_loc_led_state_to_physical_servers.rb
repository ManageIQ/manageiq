class AddLocLedStateToPhysicalServers < ActiveRecord::Migration[5.0]
  def change
    add_column :physical_servers, :loc_led_state, :string
  end
end
