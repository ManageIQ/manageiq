describe MeteringVm do
  include Spec::Support::ChargebackHelper

  let(:admin) { FactoryGirl.create(:user_admin) }
  let(:base_options) do
    {:interval_size       => 2,
     :end_interval_offset => 0,
     :ext_options         => {:tz => 'UTC'},
     :userid              => admin.userid}
  end

  let(:derived_vm_numvcpus)       { 1.0 }
  let(:derived_memory_available)  { 1000.0 }
  let(:cpu_usagemhz_rate_average) { 50.0 }
  let(:disk_usage_rate_average)   { 100.0 }
  let(:derived_memory_used)   { 100.0 }
  let(:net_usage_rate_average) { 25.0 }
  let(:derived_vm_used_disk_storage) { 1.0.gigabytes }
  let(:derived_vm_allocated_disk_storage) { 4.0.gigabytes }

  let(:starting_date) { Time.parse('2012-09-01 23:59:59Z').utc }
  let(:ts) { starting_date.in_time_zone(Metric::Helper.get_time_zone(base_options[:ext_options])) }
  let(:report_run_time) { month_end }
  let(:month_beginning) { ts.beginning_of_month.utc }
  let(:month_end) { ts.end_of_month.utc }
  let(:hours_in_month) { Time.days_in_month(month_beginning.month, month_beginning.year) * 24 }
  let(:count_of_metric_rollup) { MetricRollup.where(:timestamp => month_beginning...month_end).count }
  let(:ems) { FactoryGirl.create(:ems_vmware) }
  let(:vm) { FactoryGirl.create(:vm_vmware, :name => "test_vm", :evm_owner => admin, :ems_ref => "ems_ref", :created_on => month_beginning) }
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
      :tag_names             => "environment/prod",
      :parent_host_id        => host.id,
      :parent_ems_cluster_id => ems_cluster.id,
      :parent_ems_id         => ems.id,
      :parent_storage_id     => storage.id,
    }
  end

  context 'monthly' do
    subject { MeteringVm.build_results_for_report_MeteringVm(options).first.first }

    let(:options) { base_options.merge(:interval => 'monthly', :interval_size => 4, :entity_id => vm.id) }

    before do
      add_metric_rollups_for(vm, month_beginning...month_end, 12.hours, metric_rollup_params)
    end

    it 'calculates metering values' do
      expect(subject.cpu_allocated_metric).to eq(derived_vm_numvcpus)
      expect(subject.cpu_used_metric).to eq(cpu_usagemhz_rate_average * count_of_metric_rollup)
      expect(subject.disk_io_used_metric).to eq(disk_usage_rate_average * count_of_metric_rollup)
      expect(subject.fixed_compute_metric).to eq(count_of_metric_rollup)
      expect(subject.memory_allocated_metric).to eq(derived_memory_available)
      expect(subject.memory_used_metric).to eq(derived_memory_used * count_of_metric_rollup)
      expect(subject.metering_used_metric).to eq(count_of_metric_rollup)
      expect(subject.existence_hours_metric).to eq(month_beginning.end_of_month.day * 24)
      expect(subject.net_io_used_metric).to eq(net_usage_rate_average * count_of_metric_rollup)
      expect(subject.storage_allocated_metric).to eq(derived_vm_allocated_disk_storage)
      expect(subject.storage_used_metric).to eq(derived_vm_used_disk_storage * count_of_metric_rollup)
    end

    context 'count of used hours is different than count of metric rollups' do
      let(:used_metric_attributtes_with_zeros) do
        # create hash with metrics as keys with zeros in values
        # e.g. {"cpu_usagemhz_rate_average"=>0, "derived_memory_used"=>0, ...
        Hash[MetricRollup::METERING_USED_METRIC_FIELDS.inject([]) { |result_array, metric| result_array << [metric, 0] }]
      end

      let(:count_of_metric_rollup_with_zero_used_metric) { 20 }

      before do
        vm.metric_rollups.limit(20).each { |record| record.update(used_metric_attributtes_with_zeros) }
      end

      it 'calculates metering used hours only from used metrics' do
        expect(subject.metering_used_metric).to eq(vm.metric_rollups.count - count_of_metric_rollup_with_zero_used_metric)
        expect(subject.metering_used_metric).to eq(40)
        expect(subject.metering_used_metric).not_to eq(subject.fixed_compute_metric)
      end
    end
  end

  let(:allowed_attributes) do
    %w(start_date
       end_date
       interval_name
       display_range
       entity
       tag_name
       label_name
       fixed_compute_metric
       id
       vm_id
       vm_name
       vm_uid
       vm_guid
       owner_name
       provider_name
       provider_uid
       cpu_allocated_metric
       cpu_used_metric
       disk_io_used_metric
       memory_allocated_metric
       memory_used_metric
       net_io_used_metric
       storage_allocated_metric
       storage_used_metric
       metering_used_metric
       existence_hours_metric
       tenant_name
  )
  end

  it 'lists proper attributes' do
    expect(described_class.attribute_names).to match_array(allowed_attributes)
  end
end
