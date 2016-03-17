class AddIndexToSwitch < ActiveRecord::Migration[5.0]
  def change
    add_index :switches, :uid_ems, :unique => true
  end
end
