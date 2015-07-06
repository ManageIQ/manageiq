class FixOrderOfMultiColumnIndexOnVimPerformances < ActiveRecord::Migration
  def up
    remove_index :vim_performances, :name => "index_vim_performances_on_resource_and_timestamp"
    add_index    :vim_performances, [:resource_id, :resource_type, :capture_interval_name, :timestamp], :name => "index_vim_performances_on_resource_and_timestamp"

    remove_index :vim_performance_states, :name => "index_vim_performance_states_on_resource_and_timestamp"
    add_index    :vim_performance_states, [:resource_id, :resource_type, :timestamp], :name => "index_vim_performance_states_on_resource_and_timestamp"
  end

  def down
    remove_index :vim_performances, :name => "index_vim_performances_on_resource_and_timestamp"
    add_index    :vim_performances, [:resource_type, :resource_id, :capture_interval_name, :timestamp], :name => "index_vim_performances_on_resource_and_timestamp"

    remove_index :vim_performance_states, :name => "index_vim_performance_states_on_resource_and_timestamp"
    add_index    :vim_performance_states, [:resource_type, :resource_id, :timestamp], :name => "index_vim_performance_states_on_resource_and_timestamp"
  end
end
