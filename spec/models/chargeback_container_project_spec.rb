describe ChargebackContainerProject do
  include Spec::Support::ChargebackHelper

  let(:base_options) { {:interval_size => 1, :end_interval_offset => 0, :ext_options => {:tz => 'UTC'} } }
  let(:hourly_rate)       { 0.01 }
  let(:ts) { Time.now.in_time_zone(Metric::Helper.get_time_zone(options[:ext_options])) }
  let(:month_beginning) { ts.beginning_of_month.utc }
  let(:month_end) { ts.end_of_month.utc }
  let(:hours_in_month) { Time.days_in_month(month_beginning.month, month_beginning.year) * 24 }
  let(:ems) {FactoryGirl.create(:ems_openshift) }

  let(:hourly_variable_tier_rate) { {:variable_rate => hourly_rate.to_s} }

  let(:detail_params) do
    {
      :chargeback_rate_detail_fixed_compute_cost => {:tiers  => [hourly_variable_tier_rate],
                                                     :detail => { :source => 'compute_1'} },
      :chargeback_rate_detail_cpu_cores_used     => {:tiers => [hourly_variable_tier_rate]},
      :chargeback_rate_detail_net_io_used        => {:tiers => [hourly_variable_tier_rate]},
      :chargeback_rate_detail_memory_used        => {:tiers => [hourly_variable_tier_rate]}
    }
  end

  let!(:chargeback_rate) do
    FactoryGirl.create(:chargeback_rate, :detail_params => detail_params)
  end

  before do
    MiqRegion.seed
    ChargebackRate.seed

    EvmSpecHelper.create_guid_miq_server_zone
    @project = FactoryGirl.create(:container_project, :name => "my project", :ext_management_system => ems)

    temp = {:cb_rate => chargeback_rate, :object => ems}
    ChargebackRate.set_assignments(:compute, [temp])

    cat = FactoryGirl.create(:classification, :description => "Environment", :name => "environment", :single_value => true, :show => true)
    c = FactoryGirl.create(:classification, :name => "prod", :description => "Production", :parent_id => cat.id)
    @tag = c.tag
    @project.tag_with(@tag.name, :ns => '*')

    Timecop.travel(Time.parse('2012-09-01 23:59:59Z').utc)
  end

  after do
    Timecop.return
  end

  context "Daily" do
    let(:hours_in_day) { 24 }
    let(:options) { base_options.merge(:interval => 'daily', :entity_id => @project.id, :tag => nil) }
    let(:start_time)  { Time.parse('2012-09-01 07:00:00Z').utc }
    let(:finish_time) { Time.parse('2012-09-01 10:00:00Z').utc }

    before do
      Range.new(start_time, finish_time, true).step_value(1.hour).each do |t|
        @project.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr, :with_data,
                                                         :timestamp                => t,
                                                         :parent_ems_id            => ems.id,
                                                         :tag_names                => "",
                                                         :resource_name            => @project.name)
      end

      @metric_size = @project.metric_rollups.size
    end

    subject { ChargebackContainerProject.build_results_for_report_ChargebackContainerProject(options).first.first }

    it "cpu" do
      metric_used = used_average_for(:cpu_usage_rate_average, hours_in_day, @project)
      expect(subject.cpu_cores_used_metric).to eq(metric_used)
      expect(subject.cpu_cores_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_day)
    end

    it "memory" do
      metric_used = used_average_for(:derived_memory_used, hours_in_day, @project)
      expect(subject.memory_used_metric).to eq(metric_used)
      expect(subject.memory_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_day)
    end

    it "net io" do
      metric_used = used_average_for(:net_usage_rate_average, hours_in_day, @project)
      expect(subject.net_io_used_metric).to eq(metric_used)
      expect(subject.net_io_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_day)
    end

    it "fixed_compute" do
      expect(subject.fixed_compute_1_cost).to eq(hourly_rate * hours_in_day)
      expect(subject.fixed_compute_metric).to eq(@metric_size)
    end
  end

  context "Monthly" do
    let(:options) { base_options.merge(:interval => 'monthly', :entity_id => @project.id, :tag => nil) }
    before do
      Range.new(month_beginning, month_end, true).step_value(12.hours).each do |time|
        @project.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr, :with_data,
                                                         :timestamp                => time,
                                                         :parent_ems_id            => ems.id,
                                                         :tag_names                => "",
                                                         :resource_name            => @project.name)
      end

      @metric_size = @project.metric_rollups.size
    end

    subject { ChargebackContainerProject.build_results_for_report_ChargebackContainerProject(options).first.first }

    it "cpu" do
      metric_used = used_average_for(:cpu_usage_rate_average, hours_in_month, @project)
      expect(subject.cpu_cores_used_metric).to be_within(0.01).of(metric_used)
      expect(subject.cpu_cores_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_month)
    end

    it "memory" do
      metric_used = used_average_for(:derived_memory_used, hours_in_month, @project)
      expect(subject.memory_used_metric).to be_within(0.01).of(metric_used)
      expect(subject.memory_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_month)
    end

    it "net io" do
      metric_used = used_average_for(:net_usage_rate_average, hours_in_month, @project)
      expect(subject.net_io_used_metric).to be_within(0.01).of(metric_used)
      expect(subject.net_io_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_month)
    end

    it "fixed_compute" do
      # .to be_within(0.01) is used since theres a float error here
      expect(subject.fixed_compute_1_cost).to be_within(0.01).of(hourly_rate * hours_in_month)
      expect(subject.fixed_compute_metric).to eq(@metric_size)
    end
  end

  context "tagged project" do
    let(:options) { base_options.merge(:interval => 'monthly', :entity_id => nil, :tag => '/managed/environment/prod') }
    before do
      Range.new(month_beginning, month_end, true).step_value(12.hours).each do |time|
        @project.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr, :with_data,
                                                         :timestamp                => time,
                                                         :parent_ems_id            => ems.id,
                                                         :tag_names                => "",
                                                         :resource_name            => @project.name)
      end
    end

    subject { ChargebackContainerProject.build_results_for_report_ChargebackContainerProject(options).first.first }

    it "cpu" do
      metric_used = used_average_for(:cpu_usage_rate_average, hours_in_month, @project)
      expect(subject.cpu_cores_used_metric).to be_within(0.01).of(metric_used)
      expect(subject.cpu_cores_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_month)
    end
  end

  context "group results by tag" do
    let(:options) { base_options.merge(:interval => 'monthly', :entity_id => nil, :provider_id => 'all', :groupby_tag => 'environment') }
    before do
      Range.new(month_beginning, month_end, true).step_value(12.hours).each do |time|
        @project.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr, :with_data,
                                                      :timestamp                => time,
                                                      :parent_ems_id            => ems.id,
                                                      :tag_names                => "environment/prod",
                                                      :resource_name            => @project.name)
      end
    end

    subject { ChargebackContainerProject.build_results_for_report_ChargebackContainerProject(options).first.first }

    it "cpu" do
      metric_used = used_average_for(:cpu_usage_rate_average, hours_in_month, @project)
      expect(subject.cpu_cores_used_metric).to be_within(0.01).of(metric_used)
      expect(subject.cpu_cores_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_month)
      expect(subject.tag_name).to eq('Production')
    end
  end

  context "ignore empty metrics in fixed_compute" do
    let(:options) { base_options.merge(:interval => 'monthly', :entity_id => @project.id, :tag => nil) }
    before do
      Range.new(month_beginning, month_end, true).step_value(24.hours).each do |time|
        @project.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr, :with_data,
                                                      :timestamp                => time,
                                                      :parent_ems_id            => ems.id,
                                                      :tag_names                => "",
                                                      :resource_name            => @project.name)
        # Empty metric for fixed compute
        @project.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                                                      :timestamp                => time + 12.hours,
                                                      :cpu_usage_rate_average   => 0.0,
                                                      :derived_memory_used      => 0.0,
                                                      :parent_ems_id            => ems.id,
                                                      :tag_names                => "",
                                                      :resource_name            => @project.name)
      end

      @metric_size = @project.metric_rollups.size
    end

    subject { ChargebackContainerProject.build_results_for_report_ChargebackContainerProject(options).first.first }

    it "fixed_compute" do
      # .to be_within(0.01) is used since theres a float error here
      expect(subject.fixed_compute_1_cost).to be_within(0.01).of(hourly_rate * hours_in_month)
      expect(subject.fixed_compute_metric).to eq(@metric_size / 2)
    end
  end
end
