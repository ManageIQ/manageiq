describe MeteringContainerProject do
  include Spec::Support::ChargebackHelper

  let(:admin) { FactoryGirl.create(:user_admin) }
  let(:base_options) do
    {:interval_size       => 2,
     :end_interval_offset => 0,
     :ext_options         => {:tz => 'UTC'},
     :userid              => admin.userid}
  end

  let(:cpu_usage_rate_average) { 50.0 }
  let(:derived_memory_used)    { 100.0 }
  let(:net_usage_rate_average) { 25.0 }

  let(:starting_date) { Time.parse('2012-09-01 23:59:59Z').utc }
  let(:ts) { starting_date.in_time_zone(Metric::Helper.get_time_zone(base_options[:ext_options])) }
  let(:report_run_time) { month_end }
  let(:month_beginning) { ts.beginning_of_month.utc }
  let(:month_end) { ts.end_of_month.utc }
  let(:count_of_metric_rollup) { MetricRollup.where(:timestamp => month_beginning...month_end).count }
  let(:ems) { FactoryGirl.create(:ems_vmware) }
  let(:project) { FactoryGirl.create(:container_project, :name => "my project", :ext_management_system => ems, :created_on => month_beginning) }
  let(:hardware) { FactoryGirl.create(:hardware, :memory_mb => 8124, :cpu_total_cores => 1, :cpu_speed => 9576) }
  let(:host) { FactoryGirl.create(:host, :storages => [storage], :hardware => hardware, :vms => [vm]) }
  let(:storage) { FactoryGirl.create(:storage_target_vmware) }
  let(:ems_cluster) { FactoryGirl.create(:ems_cluster, :ext_management_system => ems, :hosts => [host]) }

  before do
    MiqRegion.seed
    ChargebackRateDetailMeasure.seed
    ChargeableField.seed
    MiqEnterprise.seed
    EvmSpecHelper.create_guid_miq_server_zone
    Timecop.travel(report_run_time)
  end

  after do
    Timecop.return
  end

  let(:metric_rollup_params) do
    {
      :parent_ems_id => ems.id,
      :tag_names     => "",
    }
  end

  context 'monthly' do
    subject { MeteringContainerProject.build_results_for_report_MeteringContainerProject(options).first.first }

    let(:options) { base_options.merge(:interval => 'monthly', :interval_size => 4, :entity_id => project.id) }

    before do
      add_metric_rollups_for(project, month_beginning...month_end, 12.hours, metric_rollup_params)
    end

    it 'calculates metering values' do
      expect(subject.cpu_cores_used_metric).to eq(cpu_usage_rate_average * count_of_metric_rollup)
      expect(subject.fixed_compute_metric).to eq(count_of_metric_rollup)
      expect(subject.memory_used_metric).to eq(derived_memory_used * count_of_metric_rollup)
      expect(subject.metering_used_metric).to eq(count_of_metric_rollup)
      expect(subject.existence_hours_metric).to eq(month_beginning.end_of_month.day * 24)
      expect(subject.net_io_used_metric).to eq(net_usage_rate_average * count_of_metric_rollup)
      expect(subject.beginning_of_resource_existence_in_report_interval).to eq(month_beginning)
      expect(subject.end_of_resource_existence_in_report_interval).to eq(month_beginning + 1.month)
    end

    context 'count of used hours is different than count of metric rollups' do
      it 'calculates metering used hours only from allocated metrics' do
        expect(subject.metering_allocated_cpu_cores_metric).to eq(60)
        expect(subject.metering_allocated_memory_metric).to eq(60)
      end

      context 'with uncompleted allocation of cpu and mem' do
        before do
          project.metric_rollups.limit(20).each { |record| record.update(:cpu_usage_rate_average => 0) }
          project.metric_rollups.limit(25).each { |record| record.update(:derived_memory_available => 0) }
        end

        it 'calculates metering used hours only from allocated metrics' do
          expect(subject.metering_allocated_cpu_cores_metric).to eq(40)
          expect(subject.metering_allocated_memory_metric).to eq(35)
        end
      end
    end
  end

  let(:report_col_options) do
    {
      "cpu_cores_used_metric"               => {:grouping => [:total]},
      "existence_hours_metric"              => {:grouping => [:total]},
      "fixed_compute_metric"                => {:grouping => [:total]},
      "metering_allocated_cpu_cores_metric" => {:grouping=>[:total]},
      "metering_allocated_memory_metric"    => {:grouping=>[:total]},
      "memory_used_metric"                  => {:grouping => [:total]},
      "metering_used_metric"                => {:grouping => [:total]},
      "net_io_used_metric"                  => {:grouping => [:total]},
    }
  end

  it 'sets grouping settings for all related columns' do
    expect(described_class.report_col_options).to eq(report_col_options)
  end
end
