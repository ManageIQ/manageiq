class RemoveHostIdFromSwitch < ActiveRecord::Migration[5.0]
  def change
    remove_column :switches, :host_id, :bigint
  end
end
