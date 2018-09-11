describe MeteringContainerImage do
  include Spec::Support::ChargebackHelper
  let(:base_options) { {:interval_size => 2, :end_interval_offset => 0, :ext_options => {:tz => 'UTC'} } }
  let(:hourly_rate)       { 0.01 }
  let(:count_hourly_rate) { 1.00 }
  let(:starting_date) { Time.parse('2012-09-01 23:59:59Z').utc }
  let(:options) { base_options }
  let(:ts) { starting_date.in_time_zone(Metric::Helper.get_time_zone(options[:ext_options])) }
  let(:report_run_time) { month_end }
  let(:month_beginning) { ts.beginning_of_month.utc }
  let(:month_end) { ts.end_of_month.utc }
  let(:hours_in_month) { Time.days_in_month(month_beginning.month, month_beginning.year) * 24 }
  let(:ems) { FactoryGirl.create(:ems_openshift) }
  let(:metric_rollup_params) { {:parent_ems_id => ems.id, :tag_names => ""} }

  before do
    MiqRegion.seed
    ChargebackRateDetailMeasure.seed
    ChargeableField.seed
    ChargebackRate.seed

    MiqEnterprise.seed

    EvmSpecHelper.create_guid_miq_server_zone
    @node = FactoryGirl.create(:container_node, :name => "node")
    @image = FactoryGirl.create(:container_image, :ext_management_system => ems)
    @label = FactoryGirl.build(:custom_attribute, :name => "version/1.2/_label-1", :value => "test/1.0.0  rc_2", :section => 'docker_labels')
    @project = FactoryGirl.create(:container_project, :name => "my project", :ext_management_system => ems)
    @group = FactoryGirl.create(:container_group, :ext_management_system => ems, :container_project => @project,
                                :container_node => @node)
    @container = FactoryGirl.create(:kubernetes_container, :container_group => @group, :container_image => @image,
                                    :limit_memory_bytes => 1.megabytes, :limit_cpu_cores => 1.0)

    Timecop.travel(report_run_time)
  end

  after do
    Timecop.return
  end

  context "Monthly" do
    let(:options) { base_options.merge(:interval => 'monthly', :entity_id => @project.id, :tag => nil) }

    before do
      add_metric_rollups_for(@container, month_beginning...month_end, 12.hours, metric_rollup_params)

      Range.new(month_beginning, month_end, true).step_value(12.hours).each do |time|
        @container.vim_performance_states << FactoryGirl.create(:vim_performance_state, :timestamp => time, :image_tag_names => "environment/prod")
      end
    end

    subject { MeteringContainerImage.build_results_for_report_MeteringContainerImage(options).first.first }

    it "allocated fields" do
      expect(subject.memory_allocated_metric).to eq(@container.limit_memory_bytes / 1.megabytes)
      expect(subject.cpu_cores_allocated_metric).to eq(@container.limit_cpu_cores)
      expect(subject.cpu_cores_allocated_metric).to eq(@container.limit_memory_bytes / 1.megabytes)
      expect(subject.beginning_of_resource_existence_in_report_interval).to eq(month_beginning)
      expect(subject.end_of_resource_existence_in_report_interval).to eq(month_beginning + 1.month)
    end
  end

  let(:report_col_options) do
    {
      "cpu_cores_allocated_metric" => {:grouping => [:total]},
      "cpu_cores_used_metric"      => {:grouping => [:total]},
      "existence_hours_metric"     => {:grouping => [:total]},
      "fixed_compute_metric"       => {:grouping => [:total]},
      "memory_allocated_metric"    => {:grouping => [:total]},
      "memory_used_metric"         => {:grouping => [:total]},
      "metering_used_metric"       => {:grouping => [:total]},
      "net_io_used_metric"         => {:grouping => [:total]},
    }
  end

  it 'sets grouping settings for all related columns' do
    expect(described_class.report_col_options).to eq(report_col_options)
  end
end
