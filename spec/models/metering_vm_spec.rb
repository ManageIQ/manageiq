RSpec.describe MeteringVm do
  include Spec::Support::ChargebackHelper

  let(:admin) { FactoryBot.create(:user_admin) }
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
  let(:ems) { FactoryBot.create(:ems_vmware) }
  let(:vm) { FactoryBot.create(:vm_vmware, :name => "test_vm", :evm_owner => admin, :ems_ref => "ems_ref", :created_on => month_beginning) }
  let(:hardware) { FactoryBot.create(:hardware, :memory_mb => 8124, :cpu_total_cores => 1, :cpu_speed => 9576) }
  let(:host) { FactoryBot.create(:host, :storages => [storage], :hardware => hardware, :vms => [vm]) }
  let(:storage) { FactoryBot.create(:storage_vmware) }
  let(:ems_cluster) { FactoryBot.create(:ems_cluster, :ext_management_system => ems, :hosts => [host]) }

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
  context 'without metric rollups' do
    let(:cores)               { 7 }
    let(:mem_mb)              { 1777 }
    let(:disk_gb)             { 7 }
    let(:disk_b)              { disk_gb * 1024**3 }
    let(:metering_used_hours) { 24 }

    let(:hardware) do
      FactoryBot.create(:hardware,
                         :cpu_total_cores => cores,
                         :memory_mb       => mem_mb,
                         :disks           => [FactoryBot.create(:disk, :size => disk_b)])
    end

    context 'for SCVMM (hyper-v)' do
      before do
        cat = FactoryBot.create(:classification, :description => "Environment", :name => "environment", :single_value => true, :show => true)
        FactoryBot.create(:classification, :name => "prod", :description => "Production", :parent_id => cat.id)
        @tag = Tag.find_by(:name => "/managed/environment/prod")
      end

      let!(:vm1) do
        vm = FactoryBot.create(:vm_microsoft, :hardware => hardware, :created_on => report_run_time - 1.day)
        vm.tag_with(@tag.name, :ns => '*')
        vm
      end

      let(:options) { base_options.merge(:interval => 'daily', :tag => '/managed/environment/prod') }

      subject { MeteringVm.build_results_for_report_ChargebackVm(options).first.first }

      it 'fixed compute is calculated properly' do
        expect(subject.fixed_compute_metric).to eq(1) # One day of fixed compute metric
      end

      it 'allocated metrics are calculated properly' do
        expect(subject.memory_allocated_metric).to  eq(mem_mb)
        expect(subject.metering_used_metric).to     eq(0) # metric rollups are not used
        expect(subject.cpu_allocated_metric).to     eq(cores)
        expect(subject.storage_allocated_metric).to eq(disk_b)
      end
    end
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
      expect(subject.beginning_of_resource_existence_in_report_interval).to eq(month_beginning)
      expect(subject.end_of_resource_existence_in_report_interval).to eq(month_beginning + 1.month)
    end

    context "vm started later then beginning of report interval and it was retired earlier then end of report interval " do
      let(:beginning_of_resource_existence) { month_beginning + 5.days }
      let(:end_of_resource_existence)       { month_beginning + 20.days }

      it 'uses datetime from Vm#created_on and Vm#retires_on' do
        vm.update(:created_on => beginning_of_resource_existence, :retires_on => end_of_resource_existence)
        vm.metric_rollups.each { |mr| mr.update(:timestamp => beginning_of_resource_existence) }

        expect(subject.beginning_of_resource_existence_in_report_interval).to eq(beginning_of_resource_existence)
        expect(subject.end_of_resource_existence_in_report_interval).to eq(end_of_resource_existence)
      end

      it 'uses datetime from Vm#created_on and Vm#updated_on when vm is disconnected' do
        vm.update(:created_on => beginning_of_resource_existence)
        vm.metric_rollups.each { |mr| mr.update(:timestamp => beginning_of_resource_existence) }

        Timecop.travel(report_run_time - 5.days - 5.hours)

        vm.disconnect_ems

        Timecop.travel(report_run_time)

        expect(subject.beginning_of_resource_existence_in_report_interval).to eq(beginning_of_resource_existence)
        expect(subject.end_of_resource_existence_in_report_interval.to_s).to eq(vm.updated_on.to_s)
        expect(subject.end_of_resource_existence_in_report_interval.to_s).to eq("2012-09-25 19:00:00 UTC")
        expect(subject.existence_hours_metric).to eq(19 * 24 + 19) # from 2012-09-06 00:00:00 UTC to 2012-09-25 19:00:00 UTC
      end
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

      it 'calculates metering used hours only from allocated metrics' do
        expect(subject.metering_allocated_cpu_metric).to eq(60)
        expect(subject.metering_allocated_memory_metric).to eq(60)
      end

      context 'with uncompleted allocation of cpu and mem' do
        before do
          vm.metric_rollups.limit(20).each { |record| record.update(:derived_vm_numvcpus => 0) }
          vm.metric_rollups.limit(25).each { |record| record.update(:derived_memory_available => 0) }
        end

        it 'calculates metering used hours only from allocated metrics' do
          expect(subject.metering_allocated_cpu_metric).to eq(40)
          expect(subject.metering_allocated_memory_metric).to eq(35)
        end
      end
    end
  end

  let(:allowed_attributes) do
    %w[start_date
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
       metering_allocated_cpu_metric
       metering_allocated_memory_metric
       metering_used_metric
       existence_hours_metric
       tenant_name
       beginning_of_resource_existence_in_report_interval
       end_of_resource_existence_in_report_interval
       report_interval_range
       report_generation_date]
  end

  it 'lists proper attributes' do
    expect(described_class.attribute_names).to match_array(allowed_attributes)
  end

  let(:report_col_options) do
    {
      "cpu_allocated_metric"             => {:grouping => [:total]},
      "cpu_used_metric"                  => {:grouping => [:total]},
      "disk_io_used_metric"              => {:grouping => [:total]},
      "existence_hours_metric"           => {:grouping => [:total]},
      "fixed_compute_metric"             => {:grouping => [:total]},
      "memory_allocated_metric"          => {:grouping => [:total]},
      "metering_allocated_cpu_metric"    => {:grouping => [:total]},
      "metering_allocated_memory_metric" => {:grouping => [:total]},
      "memory_used_metric"               => {:grouping => [:total]},
      "metering_used_metric"             => {:grouping => [:total]},
      "net_io_used_metric"               => {:grouping => [:total]},
      "storage_allocated_metric"         => {:grouping => [:total]},
      "storage_used_metric"              => {:grouping => [:total]},
    }
  end

  it 'sets grouping settings for all related columns' do
    expect(described_class.report_col_options).to eq(report_col_options)
  end
end
