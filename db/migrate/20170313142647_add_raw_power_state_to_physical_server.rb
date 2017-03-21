class AddRawPowerStateToPhysicalServer < ActiveRecord::Migration[5.0]
  def change
    add_column :physical_servers, :raw_power_state, :string
  end
end
