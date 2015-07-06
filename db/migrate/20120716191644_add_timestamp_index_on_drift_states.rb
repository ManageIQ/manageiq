class AddTimestampIndexOnDriftStates < ActiveRecord::Migration
  def change
    add_index :drift_states, :timestamp
  end
end
