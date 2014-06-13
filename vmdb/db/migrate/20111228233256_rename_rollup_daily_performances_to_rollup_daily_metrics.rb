class RenameRollupDailyPerformancesToRollupDailyMetrics < ActiveRecord::Migration
  def change
    rename_column :time_profiles, :rollup_daily_performances, :rollup_daily_metrics
  end
end
