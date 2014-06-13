class FixIndicesOnVimPerformance < ActiveRecord::Migration
  def self.up
    remove_index :vim_performances, :name => "index_vim_performances_on_resource_and_timestamp"

    add_index    :vim_performances, [:resource_id, :resource_type, :capture_interval_name, :timestamp], :name => "index_vim_performances_on_resource_and_timestamp"
    add_index    :vim_performances, [:timestamp, :capture_interval_name]
  end

  def self.down
    remove_index :vim_performances, [:timestamp, :capture_interval_name]
    remove_index :vim_performances, :name => "index_vim_performances_on_resource_and_timestamp"

    add_index    :vim_performances, [:capture_interval_name, :resource_type, :resource_id, :timestamp], :name => "index_vim_performances_on_resource_and_timestamp"
  end
end
