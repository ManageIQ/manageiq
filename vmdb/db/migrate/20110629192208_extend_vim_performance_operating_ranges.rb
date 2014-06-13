class ExtendVimPerformanceOperatingRanges < ActiveRecord::Migration
  def self.up
    add_column    :vim_performance_operating_ranges, :values, :text
    add_column    :vim_performance_operating_ranges, :days,   :integer

    remove_column :vim_performance_operating_ranges, :cpu_usagemhz_rate_average_avg_over_time_period
    remove_column :vim_performance_operating_ranges, :cpu_usagemhz_rate_average_high_over_time_period
    remove_column :vim_performance_operating_ranges, :cpu_usagemhz_rate_average_low_over_time_period
    remove_column :vim_performance_operating_ranges, :derived_memory_used_avg_over_time_period
    remove_column :vim_performance_operating_ranges, :derived_memory_used_high_over_time_period
    remove_column :vim_performance_operating_ranges, :derived_memory_used_low_over_time_period
  end

  def self.down
    add_column    :vim_performance_operating_ranges, :cpu_usagemhz_rate_average_avg_over_time_period,  :float
    add_column    :vim_performance_operating_ranges, :cpu_usagemhz_rate_average_high_over_time_period, :float
    add_column    :vim_performance_operating_ranges, :cpu_usagemhz_rate_average_low_over_time_period,  :float
    add_column    :vim_performance_operating_ranges, :derived_memory_used_avg_over_time_period,        :float
    add_column    :vim_performance_operating_ranges, :derived_memory_used_high_over_time_period,       :float
    add_column    :vim_performance_operating_ranges, :derived_memory_used_low_over_time_period,        :float

    remove_column :vim_performance_operating_ranges, :days
    remove_column :vim_performance_operating_ranges, :values
  end
end
