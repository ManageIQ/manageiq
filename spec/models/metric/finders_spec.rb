RSpec.describe Metric::Finders do
  before do
    MiqRegion.seed

    @zone = EvmSpecHelper.local_miq_server.zone
  end

  describe ".day_to_range" do
    it "should return the correct start and end dates when calling day_to_range before DST starts" do
      s, e = Metric::Finders.day_to_range("2011-03-12T05:00:00Z", TimeProfile.new(:tz => "Eastern Time (US & Canada)"))
      expect(s).to eq('2011-03-12T05:00:00Z')
      expect(e).to eq('2011-03-13T04:59:59Z')
    end

    it "should return the correct start and end dates when calling day_to_range on the day DST starts" do
      s, e = Metric::Finders.day_to_range("2011-03-13T05:00:00Z", TimeProfile.new(:tz => "Eastern Time (US & Canada)"))
      expect(s).to eq('2011-03-13T05:00:00Z')
      expect(e).to eq('2011-03-14T03:59:59Z')
    end

    it "should return the correct start and end dates when calling day_to_range after DST starts" do
      s, e = Metric::Finders.day_to_range("2011-03-14T04:00:00Z", TimeProfile.new(:tz => "Eastern Time (US & Canada)"))
      expect(s).to eq('2011-03-14T04:00:00Z')
      expect(e).to eq('2011-03-15T03:59:59Z')
    end

    it "calculates for utc" do
      time_profile = FactoryBot.create(:time_profile_utc)
      expect(Metric::Finders.day_to_range("2010-04-14T00:00:00Z", time_profile)).to eq(["2010-04-14T00:00:00Z", "2010-04-14T23:59:59Z"])
    end
  end

  describe ".find_all_by_day" do
    context "with Vm hourly performances", :with_small_vmware do
      before do
        cases = [
          "2010-04-13T21:00:00Z", 100.0,
          "2010-04-14T18:00:00Z", 1.0,
          "2010-04-14T19:00:00Z", 2.0,
          "2010-04-14T20:00:00Z", 4.0,
          "2010-04-14T21:00:00Z", 8.0,
          "2010-04-14T22:00:00Z", 15.0,
          "2010-04-15T21:00:00Z", 100.0,
        ]
        cases.each_slice(2) do |t, v|
          @vm1.metric_rollups << FactoryBot.create(
            :metric_rollup_vm_hr,
            :timestamp                  => t,
            :cpu_usage_rate_average     => v,
            :cpu_ready_delta_summation  => v * 10_000,
            :sys_uptime_absolute_latest => v,
            :min_max                    => {
              :abs_max_cpu_usage_rate_average_value     => v,
              :abs_max_cpu_usage_rate_average_timestamp => Time.parse(t).utc + 20.seconds,
              :abs_min_cpu_usage_rate_average_value     => v,
              :abs_min_cpu_usage_rate_average_timestamp => Time.parse(t).utc + 40.seconds,
            }
          )
        end
      end

      it "should find the correct rows" do
        expect(Metric::Finders.find_all_by_day(@vm1, "2010-04-14T00:00:00Z", 'hourly', @time_profile)).to match_array @vm1.metric_rollups.sort_by(&:timestamp)[1..5]
      end

      it "should find multiple resource types" do
        @host1.metric_rollups << FactoryBot.create(:metric_rollup_host_hr,
                                                   :resource  => @host1,
                                                   :timestamp => "2010-04-14T22:00:00Z")
        metrics = Metric::Finders.find_all_by_day([@vm1, @host1], "2010-04-14T00:00:00Z", 'hourly', @time_profile)
        expect(metrics.collect(&:resource_type).uniq).to match_array(%w[VmOrTemplate Host])
      end
    end

    context "with Vm realtime performances", :with_small_vmware do
      before do
        cases = [
          "2010-04-14T20:52:30Z", 100.0,
          "2010-04-14T21:51:10Z", 1.0,
          "2010-04-14T21:51:30Z", 2.0,
          "2010-04-14T21:51:50Z", 4.0,
          "2010-04-14T21:52:10Z", 8.0,
          "2010-04-14T21:52:30Z", 15.0,
          "2010-04-14T22:52:30Z", 100.0,
        ]
        cases.each_slice(2) do |t, v|
          @vm1.metrics << FactoryBot.create(
            :metric_vm_rt,
            :timestamp                  => t,
            :cpu_usage_rate_average     => v,
            :cpu_ready_delta_summation  => v * 1000, # Multiply by a factor of 1000 to make it more realistic and enable testing virtual col v_pct_cpu_ready_delta_summation
            :sys_uptime_absolute_latest => v
          )
        end
      end

      it "should find the correct rows" do
        expect(Metric::Finders.find_all_by_hour(@vm1, "2010-04-14T21:00:00Z", 'realtime')).to match_array @vm1.metrics.sort_by(&:timestamp)[1..5]
      end
    end
  end

  describe ".hour_to_range" do
    it "determines range for hour" do
      expect(Metric::Finders.hour_to_range("2010-04-14T21:00:00Z")).to eq(["2010-04-14T21:00:00Z", "2010-04-14T21:59:59Z"])
    end
  end
end
