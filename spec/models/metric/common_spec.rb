RSpec.describe Metric::Common do
  let(:host) { FactoryBot.create(:host) }
  let(:metric) do
    FactoryBot.create(:metric_rollup_host_hr,
                       :resource  => host,
                       :timestamp => Time.now.next_week(:sunday).utc
                      )
  end

  describe "#v_month" do
    it "returns the timestamp in YYYY/MM format" do
      m = Metric.new(:timestamp => Time.zone.parse("2015-01-01"))
      expect(m.v_month).to eq("2015/01")
    end
  end

  context "#apply_time_profile" do
    it "with all days and hours selected it should return true" do
      profile = FactoryBot.create(:time_profile,
                                   :description => "foo",
                                   :profile     => {:tz    => "New Delhi",
                                                    :days  => TimeProfile::ALL_DAYS,
                                                    :hours => TimeProfile::ALL_HOURS}
                                  )
      res = metric.apply_time_profile(profile)
      expect(res).to be_truthy
    end

    it "with specific days and hours selected it should return false" do
      profile = FactoryBot.create(:time_profile,
                                   :description => "foo",
                                   :profile     => {:tz    => "New Delhi",
                                                    :days  => [1],
                                                    :hours => [1]}
                                  )
      res = metric.apply_time_profile(profile)
      expect(res).to be_falsey
    end

    it "returns true if time profile were used for aggregation (and rollup record refer to it)" do
      profile = FactoryBot.create(:time_profile,
                                   :description => "foo",
                                   :profile     => {:tz    => "New Delhi",
                                                    :days  => [1],
                                                    :hours => [1]})
      profile_aggr = FactoryBot.create(:time_profile,
                                        :description => "used_for_daily_aggregation",
                                        :profile     => {:tz    => "UTC",
                                                         :days  => (2..4),
                                                         :hours => TimeProfile::ALL_HOURS})

      metric.time_profile_id = profile_aggr.id
      res = metric.apply_time_profile(profile)
      expect(res).to be_truthy
    end
  end

  it ".v_derived_cpu_total_cores_used" do
    m = Metric.new

    # cpu_rate, num_vcpus, cpu_total_cores_used
    metrics_exercises = [
      [0, 8, 0], [10, 8, 0.8], [50, 8, 4], [75, 8, 6], [100, 8, 8],
      [nil, 8, nil], [nil, 4, nil],
      [0, 0, nil], [10, 0, nil], [50, 0, nil],
      [0, nil, nil], [10, nil, nil], [50, nil, nil],
      [nil, nil, nil],
    ]

    metrics_exercises.each do |cpu_rate, num_vcpus, expected|
      m.cpu_usage_rate_average = cpu_rate
      m.derived_vm_numvcpus = num_vcpus
      expect(m.v_derived_cpu_total_cores_used).to eq(expected)
    end
  end

  describe ".for_time_range" do
    it "returns nothing for nil dates" do
      FactoryBot.create(:metric, :timestamp => 5.days.ago)
      expect(Metric.for_time_range(nil, nil)).to be_empty
    end

    it "returns a single date' worth" do
      timestamp = 5.days.ago
      good = FactoryBot.create(:metric, :timestamp => timestamp)
      FactoryBot.create(:metric, :timestamp => 4.days.ago)
      FactoryBot.create(:metric, :timestamp => 6.days.ago)
      expect(Metric.for_time_range(timestamp, timestamp)).to eq([good])
    end

    it "returns open ended date" do
      FactoryBot.create(:metric, :timestamp => 30.days.ago)
      good = FactoryBot.create(:metric, :timestamp => 5.days.ago)
      expect(Metric.for_time_range(10.days.ago, nil)).to eq([good])
    end

    it "returns range" do
      FactoryBot.create(:metric, :timestamp => 30.days.ago)
      good = FactoryBot.create(:metric, :timestamp => 5.days.ago)
      FactoryBot.create(:metric, :timestamp => 1.day.ago)
      expect(Metric.for_time_range(10.days.ago, 3.days.ago)).to eq([good])
    end
  end
end
