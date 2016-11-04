describe ChargebackVm do
  before do
    MiqRegion.seed
    ChargebackRate.seed

    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_vmware)
    cat = FactoryGirl.create(:classification, :description => "Environment", :name => "environment", :single_value => true, :show => true)
    c = FactoryGirl.create(:classification, :name => "prod", :description => "Production", :parent_id => cat.id)
    @tag = Tag.find_by_name("/managed/environment/prod")

    @admin = FactoryGirl.create(:user_admin)

    @vm1 = FactoryGirl.create(:vm_vmware, :name => "test_vm", :evm_owner => @admin, :ems_ref => "ems_ref")
    @vm1.tag_with(@tag.name, :ns => '*')

    @host1   = FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :memory_mb => 8124, :cpu_total_cores => 1, :cpu_speed => 9576), :vms => [@vm1])
    @storage = FactoryGirl.create(:storage_target_vmware)
    @host1.storages << @storage

    @ems_cluster = FactoryGirl.create(:ems_cluster, :ext_management_system => @ems)
    @ems_cluster.hosts << @host1

    @cbr = FactoryGirl.create(:chargeback_rate, :rate_type => "Compute")
    temp = {:cb_rate => @cbr, :tag => [c, "vm"]}
    ChargebackRate.set_assignments(:compute, [temp])

    @hourly_rate               = 0.01
    @count_hourly_rate         = 1.00
    @cpu_usagemhz_rate         = 50.0
    @cpu_count                 = 1.0
    @memory_available          = 1000.0
    @memory_used               = 100.0
    @disk_usage_rate           = 100.0
    @net_usage_rate            = 25.0
    @vm_used_disk_storage      = 1.0
    @vm_allocated_disk_storage = 4.0

    @options = {:interval_size       => 1,
                :end_interval_offset => 0,
                :tag                 => "/managed/environment/prod",
                :ext_options         => {:tz => "Pacific Time (US & Canada)"},
                :userid              => @admin.userid
                }

    Timecop.travel(Time.parse("2012-09-01 00:00:00 UTC"))
  end

  after do
    Timecop.return
  end

  it "succeeds without a userid" do
    @options.delete(:userid)
    expect { ChargebackVm.build_results_for_report_ChargebackVm(@options) }.not_to raise_error
  end

  context "Daily" do
    let(:hours_in_day) { 24 }

    before  do
      @options[:interval] = "daily"

      ["2012-08-31T07:00:00Z", "2012-08-31T08:00:00Z", "2012-08-31T09:00:00Z", "2012-08-31T10:00:00Z"].each do |t|
        @vm1.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                                                  :timestamp                         => t,
                                                  :cpu_usagemhz_rate_average         => @cpu_usagemhz_rate,
                                                  :derived_vm_numvcpus               => @cpu_count,
                                                  :derived_memory_available          => @memory_available,
                                                  :derived_memory_used               => @memory_used,
                                                  :disk_usage_rate_average           => @disk_usage_rate,
                                                  :net_usage_rate_average            => @net_usage_rate,
                                                  :derived_vm_used_disk_storage      => @vm_used_disk_storage.gigabytes,
                                                  :derived_vm_allocated_disk_storage => @vm_allocated_disk_storage.gigabytes,
                                                  :tag_names                         => "environment/prod",
                                                  :parent_host_id                    => @host1.id,
                                                  :parent_ems_cluster_id             => @ems_cluster.id,
                                                  :parent_ems_id                     => @ems.id,
                                                  :parent_storage_id                 => @storage.id,
                                                  :resource_name                     => @vm1.name,
                                                 )
      end
    end

    subject { ChargebackVm.build_results_for_report_ChargebackVm(@options).first.first }

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
                               :variable_rate             => @hourly_rate.to_s
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
                               :variable_rate             => @count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.cpu_allocated_metric).to eq(@cpu_count)
      expect(subject.cpu_used_metric).to eq(@cpu_usagemhz_rate)
      expect(subject.cpu_allocated_cost).to eq(@cpu_count * @count_hourly_rate * hours_in_day)
      expect(subject.cpu_used_cost).to eq(@cpu_usagemhz_rate * @hourly_rate * hours_in_day)
      expect(subject.cpu_cost).to eq(subject.cpu_allocated_cost + subject.cpu_used_cost)
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
                               :variable_rate             => @hourly_rate.to_s
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
                               :variable_rate             => @count_hourly_rate.to_s
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
                               :variable_rate             => @hourly_rate.to_s)
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.cpu_allocated_metric).to eq(@cpu_count)
      expect(subject.cpu_used_metric).to eq(@cpu_usagemhz_rate)

      expect(subject.cpu_allocated_cost).to eq(@cpu_count * @count_hourly_rate * hours_in_day)
      expect(subject.cpu_used_cost).to eq(@cpu_usagemhz_rate * @hourly_rate * hours_in_day)
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
                               :variable_rate             => @hourly_rate.to_s
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
                               :variable_rate             => @hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.memory_allocated_metric).to eq(@memory_available)
      expect(subject.memory_used_metric).to eq(@memory_used)
      expect(subject.memory_metric).to eq(subject.memory_allocated_metric + subject.memory_used_metric)

      expect(subject.memory_allocated_cost).to eq(@memory_available * @hourly_rate * hours_in_day)
      expect(subject.memory_used_cost).to eq(@memory_used * @hourly_rate * hours_in_day)
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
                               :variable_rate             => @hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.disk_io_used_metric).to eq(@disk_usage_rate)
      expect(subject.disk_io_metric).to eq(subject.disk_io_metric)
      expect(subject.disk_io_used_cost).to be_within(0.01).of(@disk_usage_rate * @hourly_rate * hours_in_day)
      expect(subject.disk_io_cost).to eq(subject.disk_io_used_cost)
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
                               :variable_rate             => @hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.net_io_used_metric).to eq(@net_usage_rate)
      expect(subject.net_io_used_cost).to eq(@net_usage_rate * @hourly_rate * hours_in_day)
      expect(subject.net_io_cost).to eq(subject.net_io_used_cost)
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
                               :variable_rate             => @count_hourly_rate.to_s
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
                               :variable_rate             => @count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.storage_allocated_metric).to eq(@vm_allocated_disk_storage.gigabytes)
      expect(subject.storage_used_metric).to eq(@vm_used_disk_storage.gigabytes)
      expect(subject.storage_metric).to eq(subject.storage_allocated_metric + subject.storage_used_metric)

      storage_allocated_cost = @vm_allocated_disk_storage * @count_hourly_rate * hours_in_day
      expect(subject.storage_allocated_cost).to eq(storage_allocated_cost)
      expect(subject.storage_used_cost).to eq(@vm_used_disk_storage * @count_hourly_rate * hours_in_day)
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

      expect(subject.storage_allocated_metric).to eq(@vm_allocated_disk_storage.gigabytes)
      expect(subject.storage_used_metric).to eq(@vm_used_disk_storage.gigabytes)
      expect(subject.storage_metric).to eq(subject.storage_allocated_metric + subject.storage_used_metric)

      expected_value = hourly_fixed_rate * hours_in_day
      expect(subject.storage_allocated_cost).to be_within(0.01).of(expected_value)

      expected_value = hourly_fixed_rate * hours_in_day
      expect(subject.storage_used_cost).to be_within(0.01).of(expected_value)
      expect(subject.storage_cost).to eq(subject.storage_allocated_cost + subject.storage_used_cost)
    end
  end

  context "Report a chargeback of a tenant" do
    before do
      @tenant = FactoryGirl.create(:tenant)
      @tenant_child = FactoryGirl.create(:tenant, :ancestry => @tenant.id)
      @vm_tenant = FactoryGirl.create(:vm_vmware, :tenant_id => @tenant_child.id, :name => "test_vm_tenant")
      ["2012-08-31T07:00:00Z", "2012-08-31T08:00:00Z", "2012-08-31T09:00:00Z", "2012-08-31T10:00:00Z"].each do |t|
        @vm_tenant.metric_rollups <<
          FactoryGirl.create(:metric_rollup_vm_hr,
                             :timestamp                         => t,
                             :cpu_usagemhz_rate_average         => @cpu_usagemhz_rate,
                             :derived_vm_numvcpus               => @cpu_count,
                             :derived_memory_available          => @memory_available,
                             :derived_memory_used               => @memory_used,
                             :disk_usage_rate_average           => @disk_usage_rate,
                             :net_usage_rate_average            => @net_usage_rate,
                             :derived_vm_used_disk_storage      => @vm_used_disk_storage.gigabytes,
                             :derived_vm_allocated_disk_storage => @vm_allocated_disk_storage.gigabytes,
                             :tag_names                         => "environment/prod",
                             :parent_host_id                    => @host1.id,
                             :parent_ems_cluster_id             => @ems_cluster.id,
                             :parent_ems_id                     => @ems.id,
                             :parent_storage_id                 => @storage.id,
                             :resource_name                     => @vm_tenant.name,
                            )
      end
      @options_tenant = {:interval_size       => 1,
                         :end_interval_offset => 0,
                         :tag                 => "/managed/environment/prod",
                         :ext_options         => {:tz => "Pacific Time (US & Canada)"},
                         :tenant_id           => @tenant.id
                        }
    end

    subject { ChargebackVm.build_results_for_report_ChargebackVm(@options_tenant).first.first }

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
    before  do
      @options[:interval] = "monthly"

      tz = Metric::Helper.get_time_zone(@options[:ext_options])
      ts = Time.now.in_time_zone(tz)
      time     = ts.beginning_of_month.utc
      end_time = ts.end_of_month.utc

      @hours_in_month = Time.days_in_month(time.month, time.year) * 24

      while time < end_time
        @vm1.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                                                  :timestamp                         => time,
                                                  :cpu_usagemhz_rate_average         => @cpu_usagemhz_rate,
                                                  :derived_vm_numvcpus               => @cpu_count,
                                                  :derived_memory_available          => @memory_available,
                                                  :derived_memory_used               => @memory_used,
                                                  :disk_usage_rate_average           => @disk_usage_rate,
                                                  :net_usage_rate_average            => @net_usage_rate,
                                                  :derived_vm_used_disk_storage      => @vm_used_disk_storage.gigabytes,
                                                  :derived_vm_allocated_disk_storage => @vm_allocated_disk_storage.gigabytes,
                                                  :tag_names                         => "environment/prod",
                                                  :parent_host_id                    => @host1.id,
                                                  :parent_ems_cluster_id             => @ems_cluster.id,
                                                  :parent_ems_id                     => @ems.id,
                                                  :parent_storage_id                 => @storage.id,
                                                  :resource_name                     => @vm1.name,
                                                 )
        time += 12.hour
      end
    end

    subject { ChargebackVm.build_results_for_report_ChargebackVm(@options).first.first }

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
                               :variable_rate             => @hourly_rate.to_s
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
                               :variable_rate             => @count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.cpu_allocated_metric).to eq(@cpu_count)
      expect(subject.cpu_used_metric).to eq(@cpu_usagemhz_rate)
      expect(subject.cpu_allocated_cost).to be_within(0.01).of(@cpu_count * @count_hourly_rate * @hours_in_month)
      expect(subject.cpu_used_cost).to be_within(0.01).of(@cpu_usagemhz_rate * @hourly_rate * @hours_in_month)
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
                               :variable_rate             => @hourly_rate.to_s)

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
                               :variable_rate             => @count_hourly_rate.to_s)

      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.cpu_allocated_metric).to eq(@cpu_count)
      expect(subject.cpu_used_metric).to eq(@cpu_usagemhz_rate)

      fixed = fixed_rate * @hours_in_month
      variable = @cpu_count * @count_hourly_rate * @hours_in_month
      expect(subject.cpu_allocated_cost).to be_within(0.01).of(fixed + variable)

      fixed = fixed_rate * @hours_in_month
      variable = @cpu_usagemhz_rate * @hourly_rate * @hours_in_month
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
                               :variable_rate             => @hourly_rate.to_s
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
                               :variable_rate             => @hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      expect(subject.memory_allocated_metric).to eq(@memory_available)
      expect(subject.memory_used_metric).to eq(@memory_used)
      expect(subject.memory_metric).to eq(subject.memory_allocated_metric + subject.memory_used_metric)

      memory_allocated_cost = @memory_available * @hourly_rate * @hours_in_month
      expect(subject.memory_allocated_cost).to be_within(0.01).of(memory_allocated_cost)
      expect(subject.memory_used_cost).to be_within(0.01).of(@memory_used * @hourly_rate * @hours_in_month)
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
                               :variable_rate             => @hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.disk_io_used_metric).to eq(@disk_usage_rate)

      expect(subject.disk_io_used_cost).to be_within(0.01).of(@disk_usage_rate * @hourly_rate * @hours_in_month)
      expect(subject.disk_io_cost).to eq(subject.disk_io_used_cost)
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
                               :variable_rate             => @hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      expect(subject.net_io_used_metric).to eq(@net_usage_rate)

      expect(subject.net_io_used_cost).to be_within(0.01).of(@net_usage_rate * @hourly_rate * @hours_in_month)
      expect(subject.net_io_cost).to eq(subject.net_io_used_cost)
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

      expect(subject.storage_allocated_metric).to eq(@vm_allocated_disk_storage.gigabytes)
      expect(subject.storage_used_metric).to eq(@vm_used_disk_storage.gigabytes)
      expect(subject.storage_metric).to eq(subject.storage_allocated_metric + subject.storage_used_metric)

      expected_value = hourly_fixed_rate * @hours_in_month
      expect(subject.storage_allocated_cost).to be_within(0.01).of(expected_value)

      expected_value = hourly_fixed_rate * @hours_in_month
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
                               :variable_rate             => @count_hourly_rate.to_s
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
                               :variable_rate             => @count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      expect(subject.storage_allocated_metric).to eq(@vm_allocated_disk_storage.gigabytes)
      expect(subject.storage_used_metric).to eq(@vm_used_disk_storage.gigabytes)
      expect(subject.storage_metric).to eq(subject.storage_allocated_metric + subject.storage_used_metric)

      expected_value = @vm_allocated_disk_storage * @count_hourly_rate * @hours_in_month
      expect(subject.storage_allocated_cost).to be_within(0.01).of(expected_value)
      expected_value = @vm_used_disk_storage * @count_hourly_rate * @hours_in_month
      expect(subject.storage_used_cost).to be_within(0.01).of(expected_value)
      expect(subject.storage_cost).to eq(subject.storage_allocated_cost + subject.storage_used_cost)
    end

    context "by owner" do
      before do
        @user = FactoryGirl.create(:user, :name => 'Test VM Owner', :userid => 'test_user')
        @vm1.update_attribute(:evm_owner, @user)

        @options = {:interval_size => 4,
                    :owner         => @user.userid,
                    :ext_options   => {:tz => "Eastern Time (US & Canada)"},
                   }
      end

      it "valid" do
        expect(subject.owner_name).to eq(@user.name)
      end

      it "not exist" do
        @user.delete
        expect { subject }.to raise_error(MiqException::Error, "Unable to find user '#{@user.userid}'")
      end
    end
  end

  describe "#get_rates" do
    let(:chargeback_rate)         { FactoryGirl.create(:chargeback_rate, :rate_type => "Compute") }
    let(:chargeback_vm)           { FactoryGirl.build(:chargeback_vm) }
    let(:rate_assignment_options) { {:cb_rate => @cbr, :object => Tenant.root_tenant} }
    let(:metric_rollup) do
      FactoryGirl.create(:metric_rollup_vm_hr, :timestamp => "2012-08-31T07:00:00Z", :tag_names => "environment/prod",
                                               :parent_host_id => @host1.id, :parent_ems_cluster_id => @ems_cluster.id,
                                               :parent_ems_id => @ems.id, :parent_storage_id => @storage.id,
                                               :resource => @vm1)
    end

    before do
      ChargebackRate.set_assignments(:compute, [rate_assignment_options])
      @rate = chargeback_vm.get_rates(metric_rollup).first
      @assigned_rate = ChargebackRate.get_assignments("Compute").first
    end

    it "return tenant chargeback detail rate" do
      expect(@rate).not_to be_nil
      expect(@rate.id).to eq(@assigned_rate[:cb_rate].id)
    end
  end

  describe ".get_keys_and_extra_fields" do
    let(:timestamp_key) { "2012-08-31T07:00:00Z" }
    let(:vm_owners)     { {@vm1.id => @vm1.evm_owner_name} }
    let(:metric_rollup) do
      FactoryGirl.create(:metric_rollup_vm_hr, :timestamp => timestamp_key, :tag_names => "environment/prod",
                         :parent_host_id => @host1.id, :parent_ems_cluster_id => @ems_cluster.id,
                         :parent_ems_id => @ems.id, :parent_storage_id => @storage.id,
                         :resource => @vm1, :resource_name => @vm1.name)
    end

    it "returns extra fields" do
      ChargebackVm.instance_variable_set(:@vm_owners, vm_owners)

      extra_fields = ChargebackVm.get_keys_and_extra_fields(metric_rollup, timestamp_key)
      expected_fields = {"vm_name" => @vm1.name, "owner_name" => @admin.name, "provider_name" => @ems.name,
                         "provider_uid" => @ems.guid, "vm_uid" => "ems_ref"}

      expect("#{metric_rollup.resource_id}_#{timestamp_key}").to eq(extra_fields.first)
      expect(extra_fields.second).to eq(expected_fields)
    end

    let(:metric_rollup_without_ems) do
      FactoryGirl.create(:metric_rollup_vm_hr, :timestamp => timestamp_key, :tag_names => "environment/prod",
                         :parent_host_id => @host1.id, :parent_ems_cluster_id => @ems_cluster.id,
                         :parent_storage_id => @storage.id,
                         :resource => @vm1, :resource_name => @vm1.name)
    end

    it "return extra fields when parent ems is missing" do
      ChargebackVm.instance_variable_set(:@vm_owners, vm_owners)

      extra_fields = ChargebackVm.get_keys_and_extra_fields(metric_rollup_without_ems, timestamp_key)
      expected_fields = {"vm_name" => @vm1.name, "owner_name" => @admin.name, "provider_name" => nil,
                         "provider_uid" => nil, "vm_uid" => "ems_ref"}

      expect("#{metric_rollup.resource_id}_#{timestamp_key}").to eq(extra_fields.first)
      expect(extra_fields.second).to eq(expected_fields)
    end
  end
end
