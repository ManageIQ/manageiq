class AddPowerStatePropertyToPhysicalServer < ActiveRecord::Migration[5.0]
  def change
    add_column :physical_servers, :power_state, :string
  end
end
