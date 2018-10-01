describe MiqReport::Generator do
  before do
    EvmSpecHelper.local_miq_server
    @user = FactoryGirl.create(:user_with_group)
    @time_profile_all = FactoryGirl.create(:time_profile_with_rollup, :tz => "UTC")
    @host1 = FactoryGirl.create(:host)
  end

  describe "#generate" do
    context "Memory Utilization Trends report (daily)" do
      before do
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
        expect(@miq_report_profile_all.table.data[0].data).to include("slope" => 100, "direction_of_trend" => "Up")
      end

      it "calculates negative slope which is 'Down' trend" do
        used_mem_down = [120, 90, 60, 30]
        create_rollup(@host1, @time_profile_all, used_mem_down)
        @miq_report_profile_all.generate_table(:userid => @user.userid)
        expect(@miq_report_profile_all.table.data[0].data).to include("slope" => -30, "direction_of_trend" => "Down")
      end

      it "calculates 0 slope which is 'Flat' trend" do
        used_mem_flat = [302, 300, 300, 302]
        create_rollup(@host1, @time_profile_all, used_mem_flat)
        @miq_report_profile_all.generate_table(:userid => @user.userid)
        expect(@miq_report_profile_all.table.data[0].data).to include("slope" => 0, "direction_of_trend" => "Flat")
      end

      it "calculates max and min trend values" do
        used_mem_up = [400, 500, 600, 700]
        create_rollup(@host1, @time_profile_all, used_mem_up)
        @miq_report_profile_all.generate_table(:userid => @user.userid)
        expect(@miq_report_profile_all.table.data[0].data).to include("min_trend_value" => used_mem_up.min,
                                                                      "max_trend_value" => used_mem_up.max)
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

  describe "creates task, queue, audit event" do
    let(:report) do
      MiqReport.new(
        :name      => "Custom VM report",
        :title     => "Custom VM report",
        :rpt_group => "Custom",
        :rpt_type  => "Custom",
        :db        => "ManageIQ::Providers::InfraManager::Vm",
      )
    end

    before do
      User.seed
      EvmSpecHelper.local_miq_server
      ServerRole.seed
      expect(AuditEvent).to receive(:success)
    end

    it "#queue_generate_table" do
      report.queue_generate_table(:userid => "admin")
      task = MiqTask.first
      expect(task).to have_attributes(
        :name   => "Generate Report: '#{report.name}'",
        :userid => "admin"
      )

      message = MiqQueue.find_by(:method_name => "_async_generate_table")
      expect(message).to have_attributes(
        :role        => "reporting",
        :zone        => nil,
        :class_name  => report.class.name,
        :method_name => "_async_generate_table"
      )

      expect(message.args.first).to eq(task.id)
    end

    it "#queue_report_result" do
      task_id = report.queue_report_result({:userid => "admin"}, {})
      task = MiqTask.find(task_id)
      expect(task).to have_attributes(
        :name   => "Generate Report: '#{report.name}'",
        :userid => "admin"
      )

      message = MiqQueue.find_by(:method_name => "build_report_result")
      expect(message).to have_attributes(
        :role        => "reporting",
        :zone        => nil,
        :class_name  => report.class.name,
        :method_name => "build_report_result"
      )

      expect(message.args.first).to eq(task_id)
    end
  end

  describe "#cols_for_report" do
    it "uses cols" do
      rpt = MiqReport.new(:db => "VmOrTemplate", :cols => %w(vendor version name))
      expect(rpt.cols_for_report).to eq(%w(vendor version name))
    end

    it "uses include" do
      rpt = MiqReport.new(:db => "VmOrTemplate", :include => {"host" => { "columns" => %w(name hostname guid)}})
      expect(rpt.cols_for_report).to eq(%w(host.name host.hostname host.guid))
    end

    it "uses extra_cols" do
      rpt = MiqReport.new(:db => "VmOrTemplate")
      expect(rpt.cols_for_report(%w(vendor))).to eq(%w(vendor))
    end

    it "derives include" do
      rpt = MiqReport.new(:db => "VmOrTemplate", :cols => %w(vendor), :col_order =>%w(host.name vendor))
      expect(rpt.cols_for_report).to match_array(%w(vendor host.name))
    end

    it "works with col, col_order and include together" do
      rpt = MiqReport.new(:db        => "VmOrTemplate",
                          :cols      => %w(vendor),
                          :col_order => %w(host.name host.hostname vendor),
                          :include   => {"host" => { "columns" => %w(name hostname)}}
                         )
      expect(rpt.cols_for_report).to match_array(%w(vendor host.name host.hostname))
    end
  end
end
