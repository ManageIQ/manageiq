class CreateVimPerformanceOperatingRanges < ActiveRecord::Migration
  def self.up
    create_table :vim_performance_operating_ranges do |t|
      t.belongs_to  :resource, :polymorphic => true, :type => :bigint
      t.bigint      :time_profile_id
      t.float       :cpu_usagemhz_rate_average_avg_over_time_period
      t.float       :cpu_usagemhz_rate_average_high_over_time_period
      t.float       :cpu_usagemhz_rate_average_low_over_time_period
      t.float       :derived_memory_used_avg_over_time_period
      t.float       :derived_memory_used_high_over_time_period
      t.float       :derived_memory_used_low_over_time_period

      t.timestamps
    end
  end

  def self.down
    drop_table :vim_performance_operating_ranges
  end
end
