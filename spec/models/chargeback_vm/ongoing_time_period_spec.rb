RSpec.describe ChargebackVm do
  let(:admin) { FactoryBot.create(:user_admin) }
  let(:start_of_all_intervals) { Time.parse('2007-01-01 00:00:00Z').utc } # 0hours, Monday, 1st of month
  let(:consumed_hours) { 17 }
  let(:midle_of_the_first_day) { start_of_all_intervals + consumed_hours.hours } # it is a Monday
  let(:report_run_time) { midle_of_the_first_day }

  let(:opt) do
    {:interval_size       => 1,
     :end_interval_offset => 0,
     :tag                 => '/managed/environment/prod',
     :ext_options         => {:tz => 'UTC'},
     :userid              => admin.userid}
  end
  let(:tag) { Tag.find_by(:name => '/managed/environment/prod') }
  let(:vm) do
    ems = FactoryBot.create(:ems_vmware)
    vm = FactoryBot.create(:vm_vmware, :name => 'test_vm', :evm_owner => admin, :ems_ref => 'ems_ref',
                            :created_on => start_of_all_intervals)
    vm.tag_with(tag.name, :ns => '*')
    host = FactoryBot.create(:host, :hardware => FactoryBot.create(:hardware,
                                                                     :memory_mb => 8124, :cpu_total_cores => 1,
                                                                     :cpu_speed => 9576), :vms => [vm])
    ems_cluster = FactoryBot.create(:ems_cluster, :ext_management_system => ems)
    ems_cluster.hosts << host
    storage = FactoryBot.create(:storage_vmware)

    Range.new(start_of_all_intervals, midle_of_the_first_day, true).step_value(1.hour).each do |time|
      vm.metric_rollups << FactoryBot.create(:metric_rollup_vm_hr,
                                              :derived_vm_numvcpus       => number_of_cpus,
                                              :cpu_usagemhz_rate_average => cpu_usagemhz,
                                              :timestamp                 => time,
                                              :tag_names                 => 'environment/prod',
                                              :parent_host_id            => host.id,
                                              :parent_ems_cluster_id     => ems_cluster.id,
                                              :parent_ems_id             => ems.id,
                                              :parent_storage_id         => storage.id,
                                              :resource_name             => vm.name,
                                             )
    end
    vm
  end
  let(:hourly_rate)               { 0.01 }
  let(:count_hourly_rate)         { 1.2 }
  let(:hourly_variable_tier_rate)       { {:variable_rate => hourly_rate.to_s} }
  let(:count_hourly_variable_tier_rate) { {:variable_rate => count_hourly_rate.to_s} }
  let(:detail_params) do
    {
      :chargeback_rate_detail_cpu_used      => {:tiers => [hourly_variable_tier_rate]},
      :chargeback_rate_detail_cpu_allocated => {:tiers => [count_hourly_variable_tier_rate]},
    }
  end

  let!(:chargeback_rate) do
    cat = FactoryBot.create(:classification, :description => 'Environment', :name => 'environment',
                             :single_value => true, :show => true)
    c = FactoryBot.create(:classification, :name => 'prod', :description => 'Production', :parent_id => cat.id)
    chargeback_rate = FactoryBot.create(:chargeback_rate, :detail_params => detail_params)
    temp = { :cb_rate => chargeback_rate, :tag => [c, 'vm'] }
    ChargebackRate.set_assignments(:compute, [temp])
  end

  before do
    MiqRegion.seed
    ChargebackRateDetailMeasure.seed
    ChargeableField.seed
    EvmSpecHelper.create_guid_miq_server_zone
    Timecop.travel(report_run_time)
    vm
  end

  after do
    Timecop.return
  end

  let(:daily_cb)   { ChargebackVm.build_results_for_report_ChargebackVm(opt.merge(:interval => 'daily')).first.first }
  let(:weekly_cb)  { ChargebackVm.build_results_for_report_ChargebackVm(opt.merge(:interval => 'weekly')).first.first }
  let(:monthly_cb) { ChargebackVm.build_results_for_report_ChargebackVm(opt.merge(:interval => 'monthly')).first.first }

  let(:number_of_cpus) { 1 }
  let(:cpu_allocated_cost) { number_of_cpus * consumed_hours * count_hourly_rate }
  let(:cpu_usagemhz) { 50 }
  let(:cpu_usage_cost) { cpu_usagemhz * consumed_hours * hourly_rate }

  it 'should calculate the same -- no matter the time range (daily/weekly/monthly)' do
    [daily_cb, weekly_cb, monthly_cb].each do |cb|
      expect(cb.start_date).to eq(report_run_time.beginning_of_month)
      expect(cb.fixed_compute_metric).to eq(consumed_hours)
      expect(cb.cpu_allocated_metric).to eq(number_of_cpus)
      expect(cb.cpu_allocated_cost).to eq(cpu_allocated_cost)
      expect(cb.cpu_used_metric).to eq(cpu_usagemhz)
      expect(cb.cpu_used_cost).to eq(cpu_usage_cost)
      expect(cb.total_cost).to eq(cpu_allocated_cost + cpu_usage_cost)
      expect(cb.total_cost).to eq(28.9) # hardcoded value here keeps us honest
    end
  end
end
