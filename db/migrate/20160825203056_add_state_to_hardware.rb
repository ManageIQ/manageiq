class AddStateToHardware < ActiveRecord::Migration[5.0]
  def change
    add_column :hardwares, :introspected, :boolean
    add_column :hardwares, :provision_state, :string
  end
end
