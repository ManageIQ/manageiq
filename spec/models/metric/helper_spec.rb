describe Metric::Helper do
  before do
    EvmSpecHelper.create_guid_miq_server_zone
  end

  describe ".remove_duplicate_timestamps" do
    let(:host) { FactoryBot.create(:host) }
    let(:metric_rollup_1) do
      FactoryBot.create(:metric_rollup,
                         :resource  => host,
                         :timestamp => Time.zone.parse("2016-01-12T00:00:00.00000000"))
    end

    # duplicate of metric_rollup_1
    let(:metric_rollup_2) do
      FactoryBot.create(:metric_rollup,
                         :resource  => host,
                         :timestamp => Time.zone.parse("2016-01-12T00:00:00.00000000"))
    end

    let(:metric_rollup_3) do
      FactoryBot.create(:metric_rollup,
                         :resource  => host,
                         :timestamp => Time.zone.parse("2016-01-12T01:00:00.00000000"))
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
