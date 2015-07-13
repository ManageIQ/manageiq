require "spec_helper"
require Rails.root.join("db/migrate/20120608194236_add_capture_interval_name_to_vmdb_metric_tables.rb")

describe AddCaptureIntervalNameToVmdbMetricTables do
  migration_context :up do
    let(:metric_stub)    { migration_stub(:VmdbMetric) }
    let(:db_metric_stub) { migration_stub(:VmdbDatabaseMetric) }

    it "sets capture_interval_name to 'hourly' in vmdb_metrics" do
      metric = metric_stub.create!

      migrate

      metric.reload.capture_interval_name.should == "hourly"
    end

    it "sets capture_interval_name to 'hourly' in vmdb_database_metrics" do
      db_metric = db_metric_stub.create!

      migrate

      db_metric.reload.capture_interval_name.should == "hourly"
    end
  end
end
