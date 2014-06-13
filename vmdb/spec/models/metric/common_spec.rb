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
end
