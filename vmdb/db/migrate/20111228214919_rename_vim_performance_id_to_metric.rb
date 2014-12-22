class RenameVimPerformanceIdToMetric < ActiveRecord::Migration
  def up
    change_table :vim_performance_tag_values do |t|
      t.belongs_to :metric, :polymorphic => true, :type => :bigint
    end

    say_with_time("Migrating data from vim_performance_id column to metric_* columns for realtime") do
      connection.update("UPDATE vim_performance_tag_values SET metric_id = vim_performance_id, metric_type = 'Metric' WHERE vim_performance_id in (SELECT id FROM metrics)")
    end

    say_with_time("Migrating data from vim_performance_id column to metric_* columns for rollups") do
      connection.update("UPDATE vim_performance_tag_values SET metric_id = vim_performance_id, metric_type = 'MetricRollup' WHERE vim_performance_id in (SELECT id FROM metric_rollups)")
    end

    change_table :vim_performance_tag_values do |t|
      t.remove_index :vim_performance_id
      t.remove       :vim_performance_id

      t.index [:metric_id, :metric_type]
    end
  end

  def down
    change_table :vim_performance_tag_values do |t|
      t.belongs_to :vim_performance,              :type => :bigint
    end

    say_with_time("Migrating data from metric_* columns to vim_performance_id column") do
      connection.update("UPDATE vim_performance_tag_values SET vim_performance_id = metric_id")
    end

    change_table :vim_performance_tag_values do |t|
      t.remove_index [:metric_id, :metric_type]
      t.remove_belongs_to :metric, :polymorphic => true

      t.index :vim_performance_id
    end
  end
end
