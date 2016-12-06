describe ChargebackContainerImage do
  before do
    MiqRegion.seed
    ChargebackRate.seed

    EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_openshift)

    @node = FactoryGirl.create(:container_node, :name => "node")
    @image = FactoryGirl.create(:container_image, :ext_management_system => @ems)
    @label = FactoryGirl.build(:custom_attribute, :name => "version_label-1", :value => "1.0.0-rc_2", :section => 'docker_labels')
    @project = FactoryGirl.create(:container_project, :name => "my project", :ext_management_system => @ems)
    @group = FactoryGirl.create(:container_group, :ext_management_system => @ems, :container_project => @project,
                                :container_node => @node)
    @container = FactoryGirl.create(:kubernetes_container, :container_group => @group, :container_image => @image)
    cat = FactoryGirl.create(:classification, :description => "Environment", :name => "environment", :single_value => true, :show => true)
    c = FactoryGirl.create(:classification, :name => "prod", :description => "Production", :parent_id => cat.id)
    @cbr = FactoryGirl.create(:chargeback_rate, :rate_type => "compute")
    ChargebackRate.set_assignments(:compute, [{ :cb_rate => @cbr, :tag => [c, "container_image"] }])

    @tag = c.tag
    @project.tag_with(@tag.name, :ns => '*')
    @image.tag_with(@tag.name, :ns => '*')

    @hourly_rate       = 0.01
    @count_hourly_rate = 1.00
    @cpu_usage_rate    = 50.0
    @cpu_count         = 1.0
    @memory_available  = 1000.0
    @memory_used       = 100.0
    @net_usage_rate    = 25.0

    @options = {:interval_size       => 1,
                :end_interval_offset => 0,
                :ext_options         => {:tz => "Pacific Time (US & Canada)"},
    }

    Timecop.travel(Time.parse("2012-09-01 00:00:00 UTC"))
  end

  after do
    Timecop.return
  end

  context "Daily" do
    let(:hours_in_day) { 24 }

    before do
      @options[:interval] = "daily"
      @options[:entity_id] = @project.id
      @options[:tag] = nil

      ["2012-08-31T07:00:00Z", "2012-08-31T08:00:00Z", "2012-08-31T09:00:00Z", "2012-08-31T10:00:00Z"].each do |t|
        @container.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                                                        :timestamp                => t,
                                                        :cpu_usage_rate_average   => @cpu_usage_rate,
                                                        :derived_vm_numvcpus      => @cpu_count,
                                                        :derived_memory_available => @memory_available,
                                                        :derived_memory_used      => @memory_used,
                                                        :net_usage_rate_average   => @net_usage_rate,
                                                        :parent_ems_id            => @ems.id,
                                                        :tag_names                => "",
                                                        :resource_name            => @project.name,
                                                        :resource_id              => @project.id)
        #state = VimPerformanceState.capture(@container)
        @container.vim_performance_states << FactoryGirl.create(:vim_performance_state,
                                                                :timestamp => t,
                                                                :image_tag_names => "environment/prod")
      end
    end

    subject { ChargebackContainerImage.build_results_for_report_ChargebackContainerImage(@options).first.first }

    let(:cbt) {
      FactoryGirl.create(:chargeback_tier,
                         :start         => 0,
                         :finish        => Float::INFINITY,
                         :fixed_rate    => 0.0,
                         :variable_rate => @hourly_rate.to_s)
    }
    let!(:cbrd) {
      FactoryGirl.create(:chargeback_rate_detail_fixed_compute_cost,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :chargeback_tiers   => [cbt])
    }
    it "fixed_compute" do
      expect(subject.fixed_compute_1_cost).to eq(@hourly_rate * hours_in_day)
    end
  end

  context "Monthly" do
    before do
      @options[:interval] = "monthly"
      @options[:entity_id] = @project.id
      @options[:tag] = nil

      tz = Metric::Helper.get_time_zone(@options[:ext_options])
      ts = Time.now.in_time_zone(tz)
      time     = ts.beginning_of_month.utc
      end_time = ts.end_of_month.utc

      @hours_in_month = Time.days_in_month(time.month, time.year) * 24

      while time < end_time
        @container.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                                                        :timestamp                => time,
                                                        :cpu_usage_rate_average   => @cpu_usage_rate,
                                                        :derived_vm_numvcpus      => @cpu_count,
                                                        :derived_memory_available => @memory_available,
                                                        :derived_memory_used      => @memory_used,
                                                        :net_usage_rate_average   => @net_usage_rate,
                                                        :parent_ems_id            => @ems.id,
                                                        :tag_names                => "",
                                                        :resource_name            => @project.name,
                                                        :resource_id              => @project.id)
        @container.vim_performance_states << FactoryGirl.create(:vim_performance_state,
                                                                :timestamp => time,
                                                                :image_tag_names => "environment/prod")
        time += 12.hours
      end
      @metric_size = @container.metric_rollups.size
    end

    subject { ChargebackContainerImage.build_results_for_report_ChargebackContainerImage(@options).first.first }

    let(:cbt) {
      FactoryGirl.create(:chargeback_tier,
                         :start         => 0,
                         :finish        => Float::INFINITY,
                         :fixed_rate    => 0.0,
                         :variable_rate => @hourly_rate.to_s)
    }
    let!(:cbrd) {
      FactoryGirl.create(:chargeback_rate_detail_fixed_compute_cost,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :chargeback_tiers   => [cbt])
    }
    it "fixed_compute" do
      # .to be_within(0.01) is used since theres a float error here
      expect(subject.fixed_compute_1_cost).to be_within(0.01).of(@hourly_rate * @hours_in_month)
    end
  end

  context "Label" do
    before do
      @options[:interval] = "monthly"
      @options[:entity_id] = @project.id
      @options[:tag] = nil
      @image.docker_labels << @label
      ChargebackRate.set_assignments(:compute, [{ :cb_rate => @cbr, :label => [@label, "container_image"] }])

      tz = Metric::Helper.get_time_zone(@options[:ext_options])
      ts = Time.now.in_time_zone(tz)
      time     = ts.beginning_of_month.utc
      end_time = ts.end_of_month.utc

      @hours_in_month = Time.days_in_month(time.month, time.year) * 24

      while time < end_time
        @container.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                                                        :timestamp                => time,
                                                        :cpu_usage_rate_average   => @cpu_usage_rate,
                                                        :derived_vm_numvcpus      => @cpu_count,
                                                        :derived_memory_available => @memory_available,
                                                        :derived_memory_used      => @memory_used,
                                                        :net_usage_rate_average   => @net_usage_rate,
                                                        :parent_ems_id            => @ems.id,
                                                        :tag_names                => "",
                                                        :resource_name            => @project.name,
                                                        :resource_id              => @project.id)
        @container.vim_performance_states << FactoryGirl.create(:vim_performance_state,
                                                                :timestamp => time,
                                                                :image_tag_names => "")
        time += 12.hours
      end
      @metric_size = @container.metric_rollups.size
    end

    subject { ChargebackContainerImage.build_results_for_report_ChargebackContainerImage(@options).first.first }

    let(:cbt) {
      FactoryGirl.create(:chargeback_tier,
                         :start         => 0,
                         :finish        => Float::INFINITY,
                         :fixed_rate    => 0.0,
                         :variable_rate => @hourly_rate.to_s)
    }
    let!(:cbrd) {
      FactoryGirl.create(:chargeback_rate_detail_fixed_compute_cost,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :source             => "compute_1",
                         :chargeback_tiers   => [cbt])
    }
    it "fixed_compute" do
      # .to be_within(0.01) is used since theres a float error here
      expect(subject.fixed_compute_1_cost).to be_within(0.01).of(@hourly_rate * @hours_in_month)
    end
  end
end
