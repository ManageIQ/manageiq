describe MiqReport::Generator do
  before do
    EvmSpecHelper.local_miq_server
    @user = FactoryGirl.create(:user_with_group)
    @time_profile_all = FactoryGirl.create(:time_profile_with_rollup, :tz => "UTC")
    @host1 = FactoryGirl.create(:host)
  end

  describe "#generate" do
    context "Memory Utilization Trends report (daily)" do
      before :each do
        @miq_report_profile_all = FactoryGirl.create(
          :miq_report,
          :db              => "VimPerformanceTrend",
          :order           => "Ascending",
          :sortby          => ["resource_name"],
          :time_profile_id => @time_profile_all.id,
          :db_options      => {:limit_col    => "max_derived_memory_available",
                               :trend_col    => "derived_memory_used",
                               :rpt_type     => "trend",
                               :start_offset => 604_800,
                               :end_offset   => 0,
                               :trend_db     => "HostPerformance",
                               :interval     => "daily",
                               :target_pcts  => [70, 80, 90]})
      end

      it "returns one row for each host" do
        used_mem_up = [400, 500, 600, 700]
        @host2 = FactoryGirl.create(:host)
        create_rollup(@host1, @time_profile_all, used_mem_up)
        create_rollup(@host2, @time_profile_all, used_mem_up)
        @miq_report_profile_all.generate_table(:userid => @user.userid)
        expect(@miq_report_profile_all.table.data.size).to eq(2)
      end

      it "calculates positive slope which is 'UP' trend" do
        used_mem_up = [400, 500, 600, 700]
        create_rollup(@host1, @time_profile_all, used_mem_up)
        @miq_report_profile_all.generate_table(:userid => @user.userid)

        slope = @miq_report_profile_all.table.data[0].data['slope']
        expect(slope).to eq(100)

        trend_direction = @miq_report_profile_all.table.data[0].data['direction_of_trend']
        expect(trend_direction).to eq("Up")
      end

      it "calculates negative slope which is 'Down' trend" do
        used_mem_down = [120, 90, 60, 30]
        create_rollup(@host1, @time_profile_all, used_mem_down)
        @miq_report_profile_all.generate_table(:userid => @user.userid)

        slope = @miq_report_profile_all.table.data[0].data['slope']
        expect(slope).to eq(-30)

        trend_direction = @miq_report_profile_all.table.data[0].data['direction_of_trend']
        expect(trend_direction).to eq("Down")
      end

      it "calculates 0 slope which is 'Flat' trend" do
        used_mem_flat = [302, 300, 300, 302]
        create_rollup(@host1, @time_profile_all, used_mem_flat)
        @miq_report_profile_all.generate_table(:userid => @user.userid)

        slope = @miq_report_profile_all.table.data[0].data['slope']
        expect(slope).to eq(0)

        trend_direction = @miq_report_profile_all.table.data[0].data['direction_of_trend']
        expect(trend_direction).to eq("Flat")
      end

      it "calculates max and min trend values" do
        used_mem_up = [400, 500, 600, 700]
        create_rollup(@host1, @time_profile_all, used_mem_up)
        @miq_report_profile_all.generate_table(:userid => @user.userid)
        report_min = @miq_report_profile_all.table.data[0].data['min_trend_value']
        report_max = @miq_report_profile_all.table.data[0].data['max_trend_value']
        expect(report_min).to eq(used_mem_up.min)
        expect(report_max).to eq(used_mem_up.max)
      end
    end

    def create_rollup(host, profile, used_mem)
      day_midnight = Time.zone.yesterday.beginning_of_day - used_mem.size.days
      used_mem.size.times do |i|
        host.metric_rollups << FactoryGirl.create(:metric_rollup_host_daily,
                                                  :timestamp                => day_midnight + i.day,
                                                  :time_profile_id          => profile.id,
                                                  :derived_memory_used      => used_mem[i],
                                                  :derived_memory_available => 1400)
      end
    end
  end
end
