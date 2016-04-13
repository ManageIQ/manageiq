describe ChargebackContainerProject do
  before do
    MiqRegion.seed
    ChargebackRate.seed

    EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_openshift)

    @project = FactoryGirl.create(:container_project, :name => "my project", :ext_management_system => @ems)
    @live_group = FactoryGirl.create(:container_group, :name => "live group", :ext_management_system => @ems)
    @disconnected_group = FactoryGirl.create(:container_group,
                                             :name                  => "disconnected group",
                                             :ext_management_system => @ems)
    @project.container_groups << @live_group
    @project.container_groups << @disconnected_group

    @cbr = FactoryGirl.create(:chargeback_rate, :rate_type => "compute")
    temp = {:cb_rate => @cbr, :object => @ems}
    ChargebackRate.set_assignments(:compute, [temp])

    @hourly_rate       = 0.01
    @count_hourly_rate = 1.00
    @cpu_usage_rate    = 50.0
    @cpu_count         = 1.0
    @memory_available  = 1000.0
    @memory_used       = 100.0
    @net_usage_rate    = 25.0

    @options = {:interval_size       => 1,
                :end_interval_offset => 0,
                :tag                 => "/managed/environment/prod",
                :ext_options         => {:tz => "Pacific Time (US & Canada)"},
                :entity_id           => @project.id
    }

    @disconnected_group.disconnect_inv

    Timecop.travel(Time.parse("2012-09-01 00:00:00 UTC"))
  end

  after do
    Timecop.return
  end

  context "Daily" do
    before do
      @options[:interval] = "daily"

      ["2012-08-31T07:00:00Z", "2012-08-31T08:00:00Z", "2012-08-31T09:00:00Z", "2012-08-31T10:00:00Z"].each do |t|
        @live_group.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                                                         :timestamp                => t,
                                                         :cpu_usage_rate_average   => @cpu_usage_rate,
                                                         :derived_vm_numvcpus      => @cpu_count,
                                                         :derived_memory_available => @memory_available,
                                                         :derived_memory_used      => @memory_used,
                                                         :net_usage_rate_average   => @net_usage_rate,
                                                         :parent_ems_id            => @ems.id,
                                                         :tag_names                => "",
                                                         :resource_name            => @live_group.name)

        @disconnected_group.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                                                                 :timestamp                => t,
                                                                 :cpu_usage_rate_average   => @cpu_usage_rate,
                                                                 :derived_vm_numvcpus      => @cpu_count,
                                                                 :derived_memory_available => @memory_available,
                                                                 :derived_memory_used      => @memory_used,
                                                                 :net_usage_rate_average   => @net_usage_rate,
                                                                 :parent_ems_id            => @ems.id,
                                                                 :tag_names                => "",
                                                                 :resource_name            => @live_group.name)
      end
      @metric_size = @live_group.metric_rollups.size + @disconnected_group.metric_rollups.size
    end

    subject { ChargebackContainerProject.build_results_for_report_ChargebackContainerProject(@options).first.first }

    it "cpu" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_cores_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly")
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @hourly_rate.to_s)
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      expect(subject.cpu_used_metric).to eq(@cpu_usage_rate * @metric_size)
      expect(subject.cpu_metric).to eq(subject.cpu_used_metric)

      expect(subject.cpu_used_cost).to eq(@cpu_usage_rate * @hourly_rate * @metric_size)
      expect(subject.cpu_cost).to eq(subject.cpu_used_cost)
    end

    it "memory" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_memory_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly")
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @hourly_rate.to_s)
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.memory_used_metric).to eq(@memory_used * @metric_size)
      expect(subject.memory_metric).to eq(subject.memory_used_metric)

      expect(subject.memory_used_cost).to eq(@memory_used * @hourly_rate * @metric_size)
      expect(subject.memory_cost).to eq(subject.memory_used_cost)
    end

    it "net io" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_net_io_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly")
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @hourly_rate.to_s)
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.net_io_used_metric).to eq(@net_usage_rate * @metric_size)
      expect(subject.net_io_metric).to eq(subject.net_io_metric)

      expect(subject.net_io_used_cost).to eq(@net_usage_rate * @hourly_rate * @metric_size)
      expect(subject.net_io_cost).to eq(subject.net_io_used_cost)
    end
  end

  context "Monthly" do
    before do
      @options[:interval] = "monthly"

      tz = Metric::Helper.get_time_zone(@options[:ext_options])
      ts = Time.now.in_time_zone(tz)
      time     = ts.beginning_of_month.utc
      end_time = ts.end_of_month.utc

      while time < end_time
        @live_group.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                                                         :timestamp                => time,
                                                         :cpu_usage_rate_average   => @cpu_usage_rate,
                                                         :derived_vm_numvcpus      => @cpu_count,
                                                         :derived_memory_available => @memory_available,
                                                         :derived_memory_used      => @memory_used,
                                                         :net_usage_rate_average   => @net_usage_rate,
                                                         :parent_ems_id            => @ems.id,
                                                         :tag_names                => "",
                                                         :resource_name            => @live_group.name)

        @disconnected_group.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                                                                 :timestamp                => time,
                                                                 :cpu_usage_rate_average   => @cpu_usage_rate,
                                                                 :derived_vm_numvcpus      => @cpu_count,
                                                                 :derived_memory_available => @memory_available,
                                                                 :derived_memory_used      => @memory_used,
                                                                 :net_usage_rate_average   => @net_usage_rate,
                                                                 :parent_ems_id            => @ems.id,
                                                                 :tag_names                => "",
                                                                 :resource_name            => @live_group.name)
        time += 12.hours
      end
      @metric_size = @live_group.metric_rollups.size + @disconnected_group.metric_rollups.size
    end

    subject { ChargebackContainerProject.build_results_for_report_ChargebackContainerProject(@options).first.first }

    it "cpu" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_cores_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly")
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @hourly_rate.to_s)
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      expect(subject.cpu_used_metric).to eq(@cpu_usage_rate * @metric_size)
      expect(subject.cpu_metric).to eq(subject.cpu_used_metric)

      expect(subject.cpu_used_cost).to eq(@cpu_usage_rate * @hourly_rate * @metric_size)
      expect(subject.cpu_cost).to eq(subject.cpu_used_cost)
    end

    it "memory" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_memory_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly")
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @hourly_rate.to_s)
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      expect(subject.memory_used_metric).to eq(@memory_used * @metric_size)
      expect(subject.memory_metric).to eq(subject.memory_used_metric)

      expect(subject.memory_used_cost).to eq(@memory_used * @hourly_rate * @metric_size)
      expect(subject.memory_cost).to eq(subject.memory_used_cost)
    end

    it "net io" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_net_io_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly")
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @hourly_rate.to_s)
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      expect(subject.net_io_used_metric).to eq(@net_usage_rate * @metric_size)
      expect(subject.net_io_metric).to eq(subject.net_io_metric)

      expect(subject.net_io_used_cost).to eq(@net_usage_rate * @hourly_rate * @metric_size)
      expect(subject.net_io_cost).to eq(subject.net_io_used_cost)
    end
  end
end
