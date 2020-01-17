RSpec.describe Metric::Helper do
  before do
    EvmSpecHelper.local_miq_server
  end

  context ".days_from_range" do
    it "should return the correct dates and times when calling days_from_range before DST starts" do
      days = Metric::Helper.days_from_range('2011-03-01T15:24:00Z', '2011-03-03T13:45:00Z', "Eastern Time (US & Canada)")
      expect(days).to eq(["2011-03-01T05:00:00Z", "2011-03-02T05:00:00Z", "2011-03-03T05:00:00Z"])
    end

    it "should return the correct dates and times when calling days_from_range when start and end dates span DST" do
      days = Metric::Helper.days_from_range('2011-03-12T11:23:00Z', '2011-03-14T14:33:00Z', "Eastern Time (US & Canada)")
      expect(days).to eq(["2011-03-12T05:00:00Z", "2011-03-13T05:00:00Z", "2011-03-14T04:00:00Z"])
    end

    it "should return the correct dates and times when calling days_from_range before DST starts" do
      days = Metric::Helper.days_from_range('2011-03-15T17:22:00Z', '2011-03-17T19:52:00Z', "Eastern Time (US & Canada)")
      expect(days).to eq(["2011-03-15T04:00:00Z", "2011-03-16T04:00:00Z", "2011-03-17T04:00:00Z"])
    end
  end

  describe ".find_for_interval_name" do
    before do
      @time_profile = FactoryBot.create(:time_profile_utc)
      @perf = FactoryBot.create(
        :metric_rollup_vm_daily,
        :timestamp    => "2010-04-14T00:00:00Z",
        :time_profile => @time_profile
      )
    end
    it "VimPerformanceDaily.find should return existing daily performances when a time_profile is passed" do
      rec = Metric::Helper.find_for_interval_name("daily", @time_profile)
      expect(rec).to eq([@perf])
    end

    it "VimPerformanceDaily.find should return existing daily performances when a time_profile is not passed, but an associated tz is" do
      rec = Metric::Helper.find_for_interval_name("daily", "UTC")
      expect(rec).to eq([@perf])
    end

    it "VimPerformanceDaily.find should return existing daily performances when defaulting to UTC time zone" do
      rec = Metric::Helper.find_for_interval_name("daily")
      expect(rec).to eq([@perf])
    end

    it "VimPerformanceDaily.find should return an empty array when a time_profile is not passed" do
      rec = Metric::Helper.find_for_interval_name("daily", "Alaska")
      expect(rec.length).to eq(0)
    end
  end

  describe ".remove_duplicate_timestamps" do
    let(:host) { FactoryBot.create(:host) }
    let(:metric_rollup_1) do
      FactoryBot.create(
        :metric_rollup,
        :resource  => host,
        :timestamp => Time.zone.parse("2016-01-12T00:00:00.00000000")
      )
    end

    # duplicate of metric_rollup_1
    let(:metric_rollup_2) do
      FactoryBot.create(
        :metric_rollup,
        :resource  => host,
        :timestamp => Time.zone.parse("2016-01-12T00:00:00.00000000")
      )
    end

    let(:metric_rollup_3) do
      FactoryBot.create(
        :metric_rollup,
        :resource  => host,
        :timestamp => Time.zone.parse("2016-01-12T01:00:00.00000000")
      )
    end

    it "returns only unique records" do
      recs = described_class.remove_duplicate_timestamps([metric_rollup_1, metric_rollup_2, metric_rollup_3])
      expect(recs).to match_array([metric_rollup_1, metric_rollup_3])
    end

    it "dedups a given scope" do
      recs = described_class.remove_duplicate_timestamps(MetricRollup.where(:id => [metric_rollup_1, metric_rollup_2, metric_rollup_3]))
      expect(recs).to match_array([metric_rollup_1, metric_rollup_3])
    end

    it "returns only unique records and merge values with the same timestamp" do
      metric_rollup_1.cpu_usage_rate_average = nil
      metric_rollup_1.save
      metric_rollup_2.cpu_usage_rate_average = 500
      metric_rollup_2.save

      metric_rollup_3.timestamp = metric_rollup_1.timestamp
      metric_rollup_3.net_usage_rate_average = 1500
      metric_rollup_3.save
      recs = described_class.remove_duplicate_timestamps([metric_rollup_1, metric_rollup_2, metric_rollup_3])

      expect(recs.length).to eq(1)
      expect(recs.first.cpu_usage_rate_average).to eq(500)
      expect(recs.first.net_usage_rate_average).to eq(1500)
    end

    let(:ems_event) do
      FactoryBot.create(:ems_event, :timestamp => Time.zone.parse("2016-01-12T01:00:00.00000000"))
    end

    it "returns origin set of records, some input records are not MetricRollup and Metric" do
      recs = described_class.remove_duplicate_timestamps([metric_rollup_1, metric_rollup_2, ems_event])
      expect(recs).to match_array([metric_rollup_1, metric_rollup_2, ems_event])
    end
  end
end
