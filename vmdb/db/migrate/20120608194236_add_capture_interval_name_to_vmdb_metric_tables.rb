class AddCaptureIntervalNameToVmdbMetricTables < ActiveRecord::Migration
  class VmdbMetric < ActiveRecord::Base; end
  class VmdbDatabaseMetric < ActiveRecord::Base; end

  def up
    add_column :vmdb_metrics,          :capture_interval_name, :string
    add_column :vmdb_database_metrics, :capture_interval_name, :string

    say_with_time("Set capture_interval_name to 'hourly' in vmdb_metrics") do
      VmdbMetric.update_all(:capture_interval_name => 'hourly')
    end

    say_with_time("Set capture_interval_name to 'hourly' in vmdb_database_metrics") do
      VmdbDatabaseMetric.update_all(:capture_interval_name => 'hourly')
    end
  end

  def down
    remove_column :vmdb_metrics,          :capture_interval_name
    remove_column :vmdb_database_metrics, :capture_interval_name
  end
end
