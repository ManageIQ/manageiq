class MoveVimPerformanceCountersToVimPerformanceMetrics < ActiveRecord::Migration
  class VimPerformanceCounter < ActiveRecord::Base; end

  def self.up
    add_column :vim_performance_metrics, :counters, :text

    # Collect the existing counters into their respective hash values
    counters_by_id = {}
    say_with_time("Collect VimPerformanceCounter records") do
      VimPerformanceCounter.all.each do |c|
        counters_by_id[c.id] = {
          :counter_key           => "#{c.group_info.downcase}_#{c.name_info.downcase}_#{c.stats.downcase}_#{c.rollup.downcase}",
          :rollup                => c.rollup.downcase,
          :precision             => (c.unit_key.downcase == 'percent') ? 0.01 : 1,
          :vim_key               => c.vim_key,
          :instance              => c.instance,
          :capture_interval      => c.capture_interval.to_s,
          :capture_interval_name => c.capture_interval_name.to_s,
        }
      end
      counters_by_id = YAML.dump(counters_by_id)
    end

    say_with_time("Update VimPerformanceMetric counters") do
      begin
        connection.execute("UPDATE vim_performance_metrics SET counters = '#{counters_by_id}'")
      rescue Exception
        puts "An error has occurred during an update of vim_performance_metrics."
        puts "  Run the script tools/perf_purge_processed_metrics.rb to clear"
        puts "  out any metrics that have already been processed."
        raise
      end
    end

    drop_table :vim_performance_counters
  end

  def self.down
    remove_column :vim_performance_metrics, :counters

    create_table :vim_performance_counters do |t|
      t.column :group_info,            :string
      t.column :name_info,             :string
      t.column :stats,                 :string
      t.column :rollup,                :string
      t.column :instance,              :string
      t.column :capture_interval,      :integer
      t.column :capture_interval_name, :string
      t.column :group_label,           :string
      t.column :name_label,            :string
      t.column :unit_key,              :string
      t.column :unit_label,            :string
      t.column :vim_key,               :string
      t.column :reserved,              :text
    end
  end
end
