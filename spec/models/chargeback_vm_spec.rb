describe ChargebackVm do
  let(:admin) { FactoryGirl.create(:user_admin) }
  let(:base_options) do
    {:interval_size       => 1,
     :end_interval_offset => 0,
     :tag                 => '/managed/environment/prod',
     :ext_options         => {:tz => 'Pacific Time (US & Canada)'},
     :userid              => admin.userid}
  end
  let(:hourly_rate)               { 0.01 }
  let(:count_hourly_rate)         { 1.00 }
  let(:cpu_count)                 { 1.0 }
  let(:memory_available)          { 1000.0 }
  let(:vm_allocated_disk_storage) { 4.0 }

  let(:ts) { Time.now.in_time_zone(Metric::Helper.get_time_zone(options[:ext_options])) }
  let(:month_beginning) { ts.beginning_of_month.utc }
  let(:month_end) { ts.end_of_month.utc }
  let(:hours_in_month) { Time.days_in_month(month_beginning.month, month_beginning.year) * 24 }
  let(:ems) { FactoryGirl.create(:ems_vmware) }

  before do
    MiqRegion.seed
    ChargebackRate.seed

    EvmSpecHelper.create_guid_miq_server_zone
    cat = FactoryGirl.create(:classification, :description => "Environment", :name => "environment", :single_value => true, :show => true)
    c = FactoryGirl.create(:classification, :name => "prod", :description => "Production", :parent_id => cat.id)
    @tag = Tag.find_by_name("/managed/environment/prod")

    @vm1 = FactoryGirl.create(:vm_vmware, :name => "test_vm", :evm_owner => admin, :ems_ref => "ems_ref")
    @vm1.tag_with(@tag.name, :ns => '*')

    @host1   = FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :memory_mb => 8124, :cpu_total_cores => 1, :cpu_speed => 9576), :vms => [@vm1])
    @storage = FactoryGirl.create(:storage_target_vmware)
    @host1.storages << @storage

    @ems_cluster = FactoryGirl.create(:ems_cluster, :ext_management_system => ems)
    @ems_cluster.hosts << @host1

    @cbr = FactoryGirl.create(:chargeback_rate, :rate_type => "Compute")
    temp = {:cb_rate => @cbr, :tag => [c, "vm"]}
    ChargebackRate.set_assignments(:compute, [temp])

    Timecop.travel(Time.parse("2012-09-01 00:00:00 UTC"))
  end

  after do
    Timecop.return
  end

  let(:report_static_fields) { %w(vm_name) }

  it "uses static fields" do
    expect(described_class.report_static_cols).to match_array(report_static_fields)
  end

  it "succeeds without a userid" do
    options = base_options.except(:userid)
    expect { ChargebackVm.build_results_for_report_ChargebackVm(options) }.not_to raise_error
  end

  context "by service" do
    let(:options) { base_options.merge(:interval => 'monthly', :interval_size => 4, :service_id => @service.id) }
    before(:each) do
      @service = FactoryGirl.create(:service)
      @service << @vm1
      @service.save

      @vm2 = FactoryGirl.create(:vm_vmware, :name => "test_vm 2", :evm_owner => admin)

      Range.new(month_beginning, month_end, true).step_value(12.hours).each do |time|
        [@vm1, @vm2].each do |vm|
          vm.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr, :with_data,
                                                  :timestamp                         => time,
                                                  :tag_names                         => "environment/prod",
                                                  :parent_host_id                    => @host1.id,
                                                  :parent_ems_cluster_id             => @ems_cluster.id,
                                                  :parent_ems_id                     => ems.id,
                                                  :parent_storage_id                 => @storage.id,
                                                  :resource_name                     => @vm1.name,
                                                 )
        end
      end

      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_allocated,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
    end

    it "only includes VMs belonging to service in results" do
      result = described_class.build_results_for_report_ChargebackVm(options)
      expect(result).not_to be_nil
      expect(result.first.all? { |r| r.vm_name == "test_vm" })
    end
  end

  def used_average_for(metric, hours_in_interval)
    @vm1.metric_rollups.sum(&metric) / hours_in_interval
  end

  context "Daily" do
    let(:hours_in_day) { 24 }
    let(:options) { base_options.merge(:interval => 'daily') }

    before  do
      ["2012-08-31T07:00:00Z", "2012-08-31T08:00:00Z", "2012-08-31T09:00:00Z", "2012-08-31T10:00:00Z"].each do |t|
        @vm1.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr, :with_data,
                                                  :timestamp                         => t,
                                                  :tag_names                         => "environment/prod",
                                                  :parent_host_id                    => @host1.id,
                                                  :parent_ems_cluster_id             => @ems_cluster.id,
                                                  :parent_ems_id                     => ems.id,
                                                  :parent_storage_id                 => @storage.id,
                                                  :resource_name                     => @vm1.name,
                                                 )
      end
    end

    subject { ChargebackVm.build_results_for_report_ChargebackVm(options).first.first }

    it "cpu" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_allocated,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.cpu_allocated_metric).to eq(cpu_count)
      used_metric = used_average_for(:cpu_usagemhz_rate_average, hours_in_day)
      expect(subject.cpu_used_metric).to eq(used_metric)

      expect(subject.cpu_allocated_cost).to eq(cpu_count * count_hourly_rate * hours_in_day)
      expect(subject.cpu_used_cost).to eq(used_metric * hourly_rate * hours_in_day)
      expect(subject.cpu_cost).to eq(subject.cpu_allocated_cost + subject.cpu_used_cost)
    end

    it "reports Vm Guid" do
      expect(subject.vm_guid).to eq(@vm1.guid)
    end

    it "cpu_vm_and_cpu_container_project" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_allocated,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_cores_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly")
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 1.0,
                               :variable_rate             => hourly_rate.to_s)
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.cpu_allocated_metric).to eq(cpu_count)
      used_metric = used_average_for(:cpu_usagemhz_rate_average, hours_in_day)
      expect(subject.cpu_used_metric).to eq(used_metric)

      expect(subject.cpu_allocated_cost).to eq(cpu_count * count_hourly_rate * hours_in_day)
      expect(subject.cpu_used_cost).to eq(used_metric * hourly_rate * hours_in_day)
      expect(subject.cpu_cost).to eq(subject.cpu_allocated_cost + subject.cpu_used_cost)
    end

    it "memory" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_memory_allocated,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      cbrd = FactoryGirl.build(:chargeback_rate_detail_memory_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.memory_allocated_metric).to eq(memory_available)
      used_metric = used_average_for(:derived_memory_used, hours_in_day)
      expect(subject.memory_used_metric).to eq(used_metric)
      expect(subject.memory_metric).to eq(subject.memory_allocated_metric + subject.memory_used_metric)

      expect(subject.memory_allocated_cost).to eq(memory_available * hourly_rate * hours_in_day)
      expect(subject.memory_used_cost).to eq(used_metric * hourly_rate * hours_in_day)
      expect(subject.memory_cost).to eq(subject.memory_allocated_cost + subject.memory_used_cost)
    end

    it "disk io" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_disk_io_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      used_metric = used_average_for(:disk_usage_rate_average, hours_in_day)
      expect(subject.disk_io_used_metric).to eq(used_metric)
      expect(subject.disk_io_used_cost).to be_within(0.01).of(used_metric * hourly_rate * hours_in_day)
    end

    it "net io" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_net_io_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      used_metric = used_average_for(:net_usage_rate_average, hours_in_day)
      expect(subject.net_io_used_metric).to eq(used_metric)
      expect(subject.net_io_used_cost).to eq(used_metric * hourly_rate * hours_in_day)
    end

    it "storage" do
      cbdm = FactoryGirl.create(:chargeback_rate_detail_measure_bytes)
      cbrd = FactoryGirl.build(:chargeback_rate_detail_storage_used,
                               :chargeback_rate_id                => @cbr.id,
                               :per_time                          => "hourly",
                               :metric                            => "derived_vm_used_disk_storage",
                               :per_unit                          => "gigabytes",
                               :chargeback_rate_detail_measure_id => cbdm.id
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      cbrd = FactoryGirl.build(:chargeback_rate_detail_storage_allocated,
                               :chargeback_rate_id                => @cbr.id,
                               :per_time                          => "hourly",
                               :per_unit                          => "gigabytes",
                               :metric                            => "derived_vm_allocated_disk_storage",
                               :chargeback_rate_detail_measure_id => cbdm.id
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      used_metric = used_average_for(:derived_vm_used_disk_storage, hours_in_day)
      expect(subject.storage_used_metric).to eq(used_metric)
      expect(subject.storage_used_cost).to eq(used_metric / 1.gigabyte * count_hourly_rate * hours_in_day)

      expect(subject.storage_allocated_metric).to eq(vm_allocated_disk_storage.gigabytes)
      storage_allocated_cost = vm_allocated_disk_storage * count_hourly_rate * hours_in_day
      expect(subject.storage_allocated_cost).to eq(storage_allocated_cost)

      expect(subject.storage_metric).to eq(subject.storage_allocated_metric + subject.storage_used_metric)
      expect(subject.storage_cost).to eq(subject.storage_allocated_cost + subject.storage_used_cost)
    end

    let(:hourly_fixed_rate) { 10.0 }

    it "storage with only fixed rates" do
      cbdm = FactoryGirl.create(:chargeback_rate_detail_measure_bytes)
      cbrd = FactoryGirl.build(:chargeback_rate_detail_storage_used,
                               :chargeback_rate_id                => @cbr.id,
                               :per_time                          => "hourly",
                               :chargeback_rate_detail_measure_id => cbdm.id)

      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => hourly_fixed_rate,
                               :variable_rate             => 0.0)

      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      cbrd = FactoryGirl.build(:chargeback_rate_detail_storage_allocated,
                               :chargeback_rate_id                => @cbr.id,
                               :per_time                          => "hourly",
                               :chargeback_rate_detail_measure_id => cbdm.id)

      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => hourly_fixed_rate,
                               :variable_rate             => 0.0)

      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.storage_allocated_metric).to eq(vm_allocated_disk_storage.gigabytes)

      used_metric = used_average_for(:derived_vm_used_disk_storage, hours_in_day)
      expect(subject.storage_used_metric).to eq(used_metric)
      expect(subject.storage_metric).to eq(subject.storage_allocated_metric + subject.storage_used_metric)

      expected_value = hourly_fixed_rate * hours_in_day
      expect(subject.storage_allocated_cost).to be_within(0.01).of(expected_value)

      expected_value = hourly_fixed_rate * hours_in_day
      expect(subject.storage_used_cost).to be_within(0.01).of(expected_value)
      expect(subject.storage_cost).to eq(subject.storage_allocated_cost + subject.storage_used_cost)
    end
  end

  context "Report a chargeback of a tenant" do
    let(:options_tenant) { base_options.merge(:tenant_id => @tenant.id) }
    before do
      @tenant = FactoryGirl.create(:tenant)
      @tenant_child = FactoryGirl.create(:tenant, :ancestry => @tenant.id)
      @vm_tenant = FactoryGirl.create(:vm_vmware, :tenant_id => @tenant_child.id, :name => "test_vm_tenant")
      ["2012-08-31T07:00:00Z", "2012-08-31T08:00:00Z", "2012-08-31T09:00:00Z", "2012-08-31T10:00:00Z"].each do |t|
        @vm_tenant.metric_rollups <<
          FactoryGirl.create(:metric_rollup_vm_hr, :with_data,
                             :timestamp                         => t,
                             :tag_names                         => "environment/prod",
                             :parent_host_id                    => @host1.id,
                             :parent_ems_cluster_id             => @ems_cluster.id,
                             :parent_ems_id                     => ems.id,
                             :parent_storage_id                 => @storage.id,
                             :resource_name                     => @vm_tenant.name,
                            )
      end
    end

    subject { ChargebackVm.build_results_for_report_ChargebackVm(options_tenant).first.first }

    it "report a chargeback of a subtenant" do
      tier = FactoryGirl.create(:chargeback_tier)
      FactoryGirl.create(:chargeback_rate_detail_cpu_allocated,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :chargeback_tiers   => [tier],
                        )
      expect(subject.vm_name).to eq(@vm_tenant.name)
    end
  end
  context "Monthly" do
    let(:options) { base_options.merge(:interval => 'monthly') }
    before  do
      Range.new(month_beginning, month_end, true).step_value(12.hours).each do |time|
        @vm1.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr, :with_data,
                                                  :timestamp                         => time,
                                                  :tag_names                         => "environment/prod",
                                                  :parent_host_id                    => @host1.id,
                                                  :parent_ems_cluster_id             => @ems_cluster.id,
                                                  :parent_ems_id                     => ems.id,
                                                  :parent_storage_id                 => @storage.id,
                                                  :resource_name                     => @vm1.name,
                                                 )
      end
    end

    subject { ChargebackVm.build_results_for_report_ChargebackVm(options).first.first }

    it "cpu" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0,
                               :variable_rate             => hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_allocated,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0,
                               :variable_rate             => count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.cpu_allocated_metric).to eq(cpu_count)
      used_metric = used_average_for(:cpu_usagemhz_rate_average, hours_in_month)
      expect(subject.cpu_used_metric).to be_within(0.01).of(used_metric)
      expect(subject.cpu_used_cost).to be_within(0.01).of(used_metric * hourly_rate * hours_in_month)
      expect(subject.cpu_allocated_cost).to be_within(0.01).of(cpu_count * count_hourly_rate * hours_in_month)
    end

    let(:fixed_rate) { 10.0 }

    it "cpu with fixed and variable rate " do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly")

      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => fixed_rate,
                               :variable_rate             => hourly_rate.to_s)

      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_allocated,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly")

      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => fixed_rate,
                               :variable_rate             => count_hourly_rate.to_s)

      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.cpu_allocated_metric).to eq(cpu_count)
      used_metric = used_average_for(:cpu_usagemhz_rate_average, hours_in_month)
      expect(subject.cpu_used_metric).to be_within(0.01).of(used_metric)

      fixed = fixed_rate * hours_in_month
      variable = cpu_count * count_hourly_rate * hours_in_month
      expect(subject.cpu_allocated_cost).to be_within(0.01).of(fixed + variable)

      fixed = fixed_rate * hours_in_month
      variable = used_metric * hourly_rate * hours_in_month
      expect(subject.cpu_used_cost).to be_within(0.01).of(fixed + variable)
    end

    it "memory" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_memory_allocated,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      cbrd = FactoryGirl.build(:chargeback_rate_detail_memory_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      expect(subject.memory_allocated_metric).to eq(memory_available)
      used_metric = used_average_for(:derived_memory_used, hours_in_month)
      expect(subject.memory_used_metric).to be_within(0.01).of(used_metric)
      expect(subject.memory_metric).to eq(subject.memory_allocated_metric + subject.memory_used_metric)

      memory_allocated_cost = memory_available * hourly_rate * hours_in_month
      expect(subject.memory_allocated_cost).to be_within(0.01).of(memory_allocated_cost)
      expect(subject.memory_used_cost).to be_within(0.01).of(used_metric * hourly_rate * hours_in_month)
      expect(subject.memory_cost).to eq(subject.memory_allocated_cost + subject.memory_used_cost)
    end

    it "disk io" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_disk_io_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      used_metric = used_average_for(:disk_usage_rate_average, hours_in_month)
      expect(subject.disk_io_used_metric).to be_within(0.01).of(used_metric)

      expect(subject.disk_io_used_cost).to be_within(0.01).of(used_metric * hourly_rate * hours_in_month)
    end

    it "net io" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_net_io_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      used_metric = used_average_for(:net_usage_rate_average, hours_in_month)
      expect(subject.net_io_used_metric).to be_within(0.01).of(used_metric)
      expect(subject.net_io_used_cost).to be_within(0.01).of(used_metric * hourly_rate * hours_in_month)
    end

    let(:hourly_fixed_rate) { 10 }

    it "storage with only fixed rates" do
      cbdm = FactoryGirl.create(:chargeback_rate_detail_measure_bytes)
      cbrd = FactoryGirl.build(:chargeback_rate_detail_storage_used,
                               :chargeback_rate_id                => @cbr.id,
                               :per_time                          => "hourly",
                               :chargeback_rate_detail_measure_id => cbdm.id)

      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => hourly_fixed_rate,
                               :variable_rate             => 0.0)

      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      cbrd = FactoryGirl.build(:chargeback_rate_detail_storage_allocated,
                               :chargeback_rate_id                => @cbr.id,
                               :per_time                          => "hourly",
                               :chargeback_rate_detail_measure_id => cbdm.id)

      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => hourly_fixed_rate,
                               :variable_rate             => 0.0)

      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.storage_allocated_metric).to eq(vm_allocated_disk_storage.gigabytes)
      used_metric = used_average_for(:derived_vm_used_disk_storage, hours_in_month)
      expect(subject.storage_used_metric).to be_within(0.01).of(used_metric)
      expect(subject.storage_metric).to eq(subject.storage_allocated_metric + subject.storage_used_metric)

      expected_value = hourly_fixed_rate * hours_in_month
      expect(subject.storage_allocated_cost).to be_within(0.01).of(expected_value)

      expected_value = hourly_fixed_rate * hours_in_month
      expect(subject.storage_used_cost).to be_within(0.01).of(expected_value)
      expect(subject.storage_cost).to eq(subject.storage_allocated_cost + subject.storage_used_cost)
    end

    it "storage" do
      cbdm = FactoryGirl.create(:chargeback_rate_detail_measure_bytes)
      cbrd = FactoryGirl.build(:chargeback_rate_detail_storage_used,
                               :chargeback_rate_id                => @cbr.id,
                               :per_time                          => "hourly",
                               :chargeback_rate_detail_measure_id => cbdm.id
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      cbrd = FactoryGirl.build(:chargeback_rate_detail_storage_allocated,
                               :chargeback_rate_id                => @cbr.id,
                               :per_time                          => "hourly",
                               :chargeback_rate_detail_measure_id => cbdm.id
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      expect(subject.storage_allocated_metric).to eq(vm_allocated_disk_storage.gigabytes)
      used_metric = used_average_for(:derived_vm_used_disk_storage, hours_in_month)
      expect(subject.storage_used_metric).to be_within(0.01).of(used_metric)
      expect(subject.storage_metric).to eq(subject.storage_allocated_metric + subject.storage_used_metric)

      expected_value = vm_allocated_disk_storage * count_hourly_rate * hours_in_month
      expect(subject.storage_allocated_cost).to be_within(0.01).of(expected_value)
      expected_value = used_metric / 1.gigabytes * count_hourly_rate * hours_in_month
      expect(subject.storage_used_cost).to be_within(0.01).of(expected_value)
      expect(subject.storage_cost).to eq(subject.storage_allocated_cost + subject.storage_used_cost)
    end

    context "by owner" do
      let(:user) { FactoryGirl.create(:user, :name => 'Test VM Owner', :userid => 'test_user') }
      let(:options) { {:interval_size => 4, :owner => user.userid, :ext_options => {:tz => 'Eastern Time (US & Canada)'} } }
      before do
        @vm1.update_attribute(:evm_owner, user)
      end

      it "valid" do
        expect(subject.owner_name).to eq(user.name)
      end

      it "not exist" do
        user.delete
        expect { subject }.to raise_error(MiqException::Error, "Unable to find user '#{user.userid}'")
      end
    end
  end

  describe "#get_rates" do
    let(:chargeback_rate)         { FactoryGirl.create(:chargeback_rate, :rate_type => "Compute") }
    let(:chargeback_vm)           { ChargebackVm.new }
    let(:rate_assignment_options) { {:cb_rate => @cbr, :object => Tenant.root_tenant} }
    let(:metric_rollup) do
      FactoryGirl.create(:metric_rollup_vm_hr, :timestamp => "2012-08-31T07:00:00Z", :tag_names => "environment/prod",
                                               :parent_host_id => @host1.id, :parent_ems_cluster_id => @ems_cluster.id,
                                               :parent_ems_id => ems.id, :parent_storage_id => @storage.id,
                                               :resource => @vm1)
    end

    before do
      ChargebackRate.set_assignments(:compute, [rate_assignment_options])
      @rate = Chargeback::RatesCache.new.get(metric_rollup).first
      @assigned_rate = ChargebackRate.get_assignments("Compute").first
    end

    it "return tenant chargeback detail rate" do
      expect(@rate).not_to be_nil
      expect(@rate.id).to eq(@assigned_rate[:cb_rate].id)
    end
  end

  describe '.report_row_key' do
    let(:report_options) { Chargeback::ReportOptions.new }
    let(:timestamp_key) { 'Fri, 13 May 2016 10:40:00 UTC +00:00' }
    let(:beginning_of_day) { timestamp_key.in_time_zone.beginning_of_day }
    let(:metric_rollup) { FactoryGirl.build(:metric_rollup_vm_hr, :timestamp => timestamp_key, :resource => @vm1) }
    subject { described_class.report_row_key(metric_rollup) }
    before do
      described_class.instance_variable_set(:@options, report_options)
    end

    it { is_expected.to eq("#{metric_rollup.resource_id}_#{beginning_of_day}") }
  end

  describe '#initialize' do
    let(:report_options) { Chargeback::ReportOptions.new }
    let(:vm_owners)     { {@vm1.id => @vm1.evm_owner_name} }
    let(:metric_rollup) do
      FactoryGirl.build(:metric_rollup_vm_hr, :tag_names => 'environment/prod',
                        :parent_host_id => @host1.id, :parent_ems_cluster_id => @ems_cluster.id,
                        :parent_ems_id => ems.id, :parent_storage_id => @storage.id,
                        :resource => @vm1, :resource_name => @vm1.name)
    end

    before do
      ChargebackVm.instance_variable_set(:@vm_owners, vm_owners)
    end

    it 'sets extra fields' do
      extra_fields = ChargebackVm.new(report_options, metric_rollup).attributes
      expected_fields = {"vm_name" => @vm1.name, "owner_name" => admin.name, "provider_name" => ems.name,
                         "provider_uid" => ems.guid, "vm_uid" => "ems_ref", "vm_guid" => @vm1.guid,
                         "vm_id" => @vm1.id}

      expect(extra_fields).to include(expected_fields)
    end

    let(:metric_rollup_without_ems) do
      FactoryGirl.build(:metric_rollup_vm_hr, :tag_names => 'environment/prod',
                        :parent_host_id => @host1.id, :parent_ems_cluster_id => @ems_cluster.id,
                        :parent_storage_id => @storage.id,
                        :resource => @vm1, :resource_name => @vm1.name)
    end

    it 'sets extra fields when parent ems is missing' do
      extra_fields = ChargebackVm.new(report_options, metric_rollup_without_ems).attributes
      expected_fields = {"vm_name" => @vm1.name, "owner_name" => admin.name, "provider_name" => nil,
                         "provider_uid" => nil, "vm_uid" => "ems_ref", "vm_guid" => @vm1.guid,
                         "vm_id" => @vm1.id}

      expect(extra_fields).to include(expected_fields)
    end
  end

  context 'more rates have been selected' do
    let(:storage_chargeback_rate_1) { FactoryGirl.create(:chargeback_rate, :rate_type => "Storage") }
    let(:storage_chargeback_rate_2) { FactoryGirl.create(:chargeback_rate, :rate_type => "Storage") }
    let(:chargeback_vm)             { Chargeback::RatesCache.new }

    let(:parent_classification) { FactoryGirl.create(:classification) }
    let(:classification_1)      { FactoryGirl.create(:classification, :parent_id => parent_classification.id) }
    let(:classification_2)      { FactoryGirl.create(:classification, :parent_id => parent_classification.id) }

    let(:rate_assignment_options_1) { {:cb_rate => storage_chargeback_rate_1, :tag => [classification_1, "Storage"]} }
    let(:rate_assignment_options_2) { {:cb_rate => storage_chargeback_rate_2, :tag => [classification_2, "Storage"]} }

    let(:metric_rollup) do
      FactoryGirl.create(:metric_rollup_vm_hr, :timestamp => "2012-08-31T07:00:00Z",
                         :parent_host_id => @host1.id, :parent_ems_cluster_id => @ems_cluster.id,
                         :parent_ems_id => ems.id, :parent_storage_id => @storage.id,
                         :resource => @vm1)
    end

    before do
      @storage.tag_with([classification_1.tag.name, classification_2.tag.name], :ns => '*')
      ChargebackRate.set_assignments(:storage, [rate_assignment_options_1, rate_assignment_options_2])
    end

    it "return only one chargeback rate according to tag name of Vm" do
      [rate_assignment_options_1, rate_assignment_options_2].each do |rate_assignment|
        metric_rollup.tag_names = rate_assignment[:tag].first.tag.send(:name_path)
        uniq_rates = chargeback_vm.send(:get, metric_rollup)
        expect([rate_assignment[:cb_rate]]).to match_array(uniq_rates)
      end
    end
  end

  context "Group by tags" do
    let(:options) { base_options.merge(:interval => 'monthly', :groupby_tag => 'environment') }
    before do
      Range.new(month_beginning, month_end, true).step_value(12.hours).each do |time|
        @vm1.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr, :with_data,
                                                  :timestamp                         => time,
                                                  :tag_names                         => "environment/prod",
                                                  :parent_host_id                    => @host1.id,
                                                  :parent_ems_cluster_id             => @ems_cluster.id,
                                                  :parent_ems_id                     => ems.id,
                                                  :parent_storage_id                 => @storage.id,
                                                  :resource_name                     => @vm1.name,
        )
      end
    end

    subject { ChargebackVm.build_results_for_report_ChargebackVm(options).first.first }

    it "cpu" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
      )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => hourly_rate.to_s
      )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_allocated,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
      )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :finish                    => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => count_hourly_rate.to_s
      )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.cpu_allocated_metric).to eq(cpu_count)
      used_metric = used_average_for(:cpu_usagemhz_rate_average, hours_in_month)
      expect(subject.cpu_used_metric).to be_within(0.01).of(used_metric)
      expect(subject.tag_name).to eq('Production')
    end
  end
end
