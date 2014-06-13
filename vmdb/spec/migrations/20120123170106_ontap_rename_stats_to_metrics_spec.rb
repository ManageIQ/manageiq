require "spec_helper"
require Rails.root.join("db/migrate/20120123170106_ontap_rename_stats_to_metrics.rb")

describe OntapRenameStatsToMetrics do

  let(:storage_stat_stub)      { migration_stub(:MiqStorageStat) }
  let(:storage_metric_stub)    { migration_stub(:MiqStorageMetric) }

  migration_context :up do
    it "changes *Stats to *Metrics" do
      changed   = storage_stat_stub.create!(:type => "FooStat")
      unchanged = storage_stat_stub.create!(:type => "Unchanged")
      changed_id, unchanged_id = changed.id, unchanged.id

      migrate

      storage_metric_stub.find(changed_id).type.should   == 'FooMetric'
      storage_metric_stub.find(unchanged_id).type.should == 'Unchanged'
    end
  end

  migration_context :down do
    it "changes *Metric records back to *Stats" do
      changed   = storage_metric_stub.create!(:type => 'BarMetric')
      unchanged = storage_metric_stub.create!(:type => 'Unchanged')
      changed_id, unchanged_id = changed.id, unchanged.id

      migrate

      storage_stat_stub.find(changed_id).type.should   == 'BarStat'
      storage_stat_stub.find(unchanged_id).type.should == 'Unchanged'
    end
  end
end
