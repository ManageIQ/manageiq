require "spec_helper"

describe Metric::Common do
  before(:each) do
    host   = FactoryGirl.create(:host)
    @metric = FactoryGirl.create(:metric_rollup_host_hr,
                                 :resource  => host,
                                 :timestamp => Time.now.next_week(:sunday).utc
                                )
  end

  context "#apply_time_profile_hourly" do
    it "with all days and hours selected it should return true" do
      profile = FactoryGirl.create(:time_profile,
                                   :description => "foo",
                                   :profile     => {:tz    => "New Delhi",
                                                    :days  => TimeProfile::ALL_DAYS,
                                                    :hours => TimeProfile::ALL_HOURS}
                                  )
      res = @metric.apply_time_profile_hourly(profile)
      res.should be_true
    end

    it "with specific days and hours selected it should return false" do
      profile = FactoryGirl.create(:time_profile,
                                   :description => "foo",
                                   :profile     => {:tz    => "New Delhi",
                                                    :days  => [1],
                                                    :hours => [1]}
                                  )
      res = @metric.apply_time_profile_hourly(profile)
      res.should be_false
    end
  end

  context "#apply_time_profile_daily" do
    it "with all days selected it should return true" do
      profile = FactoryGirl.create(:time_profile,
                                   :description => "foo",
                                   :profile     => {:tz    => "New Delhi",
                                                    :days  => TimeProfile::ALL_DAYS,
                                                    :hours => [1]}
                                  )
      res = @metric.apply_time_profile_daily(profile)
      res.should be_true
    end

    it "with specific days selected it should return false" do
      profile = FactoryGirl.create(:time_profile,
                                   :description => "foo",
                                   :profile     => {:tz    => "New Delhi",
                                                    :days  => [1, 2],
                                                    :hours => [1]}
                                  )
      res = @metric.apply_time_profile_daily(profile)
      res.should be_false
    end
  end

  it ".v_derived_logical_cpus_used" do
    m = Metric.new

    # cpu_rate, num_vcpus, logical_cpus_used
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
      expect(m.v_derived_logical_cpus_used).to eq(expected)
    end
  end
end
