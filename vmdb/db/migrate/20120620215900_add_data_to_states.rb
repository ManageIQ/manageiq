class AddDataToStates < ActiveRecord::Migration
  def up
    add_column :states, :data, :text
  end

  def down
    remove_column :states, :data
  end
end
