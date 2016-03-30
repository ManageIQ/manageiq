describe Chargeback do
  before do
    MiqRegion.seed
    ChargebackRate.seed

    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_vmware)
    cat = FactoryGirl.create(:classification, :description => "Environment", :name => "environment", :single_value => true, :show => true)
    c = FactoryGirl.create(:classification, :name => "prod", :description => "Production", :parent_id => cat.id)
    @tag = Tag.find_by_name("/managed/environment/prod")

    @vm1 = FactoryGirl.create(:vm_vmware, :name => "test_vm")
    @vm1.tag_with(@tag.name, :ns => '*')

    @host1   = FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :memory_mb => 8124, :cpu_total_cores => 1, :cpu_speed => 9576), :vms => [@vm1])
    @storage = FactoryGirl.create(:storage_target_vmware)
    @host1.storages << @storage

    @ems_cluster = FactoryGirl.create(:ems_cluster, :ext_management_system => @ems)
    @ems_cluster.hosts << @host1
    @admin = FactoryGirl.create(:user_admin)

    @cbr = FactoryGirl.create(:chargeback_rate, :rate_type => "compute")
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
    expect { Chargeback.build_results_for_report_chargeback(@options) }.not_to raise_error
  end

  context "Daily" do
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
      @metric_size = @vm1.metric_rollups.size
    end

    subject { Chargeback.build_results_for_report_chargeback(@options).first.first }

    it "cpu" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :end                       => Float::INFINITY,
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
                               :end                       => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      expect(subject.cpu_allocated_metric).to eq(@cpu_count * @metric_size)
      expect(subject.cpu_used_metric).to eq(@cpu_usagemhz_rate * @metric_size)
      expect(subject.cpu_metric).to eq(subject.cpu_allocated_metric + subject.cpu_used_metric)

      expect(subject.cpu_allocated_cost).to eq(@cpu_count * @count_hourly_rate * @metric_size)
      expect(subject.cpu_used_cost).to eq(@cpu_usagemhz_rate * @hourly_rate * @metric_size)
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
                               :end                       => Float::INFINITY,
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
                               :end                       => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.memory_allocated_metric).to eq(@memory_available * @metric_size)
      expect(subject.memory_used_metric).to eq(@memory_used * @metric_size)
      expect(subject.memory_metric).to eq(subject.memory_allocated_metric + subject.memory_used_metric)

      expect(subject.memory_allocated_cost).to eq(@memory_available * @hourly_rate * @metric_size)
      expect(subject.memory_used_cost).to eq(@memory_used * @hourly_rate * @metric_size)
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
                               :end                       => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.disk_io_used_metric).to eq(@disk_usage_rate * @metric_size)
      expect(subject.disk_io_metric).to eq(subject.disk_io_metric)

      expect(subject.disk_io_used_cost).to eq(@disk_usage_rate * @hourly_rate * @metric_size)
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
                               :end                       => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.net_io_used_metric).to eq(@net_usage_rate * @metric_size)
      expect(subject.net_io_metric).to eq(subject.net_io_metric)

      expect(subject.net_io_used_cost).to eq(@net_usage_rate * @hourly_rate * @metric_size)
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
                               :end                       => Float::INFINITY,
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
                               :end                       => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.storage_allocated_metric).to eq(@vm_allocated_disk_storage.gigabytes * @metric_size)
      expect(subject.storage_used_metric).to eq(@vm_used_disk_storage.gigabytes * @metric_size)
      expect(subject.storage_metric).to eq(subject.storage_allocated_metric + subject.storage_used_metric)

      expect(subject.storage_allocated_cost).to eq(@vm_allocated_disk_storage.gigabytes *
                                                   @count_hourly_rate *
                                                   @metric_size)
      expect(subject.storage_used_cost).to eq(@vm_used_disk_storage.gigabytes * @count_hourly_rate * @metric_size)
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

    subject { Chargeback.build_results_for_report_chargeback(@options_tenant).first.first }

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
      @metric_size = @vm1.metric_rollups.size
    end

    subject { Chargeback.build_results_for_report_chargeback(@options).first.first }

    it "cpu" do
      cbrd = FactoryGirl.build(:chargeback_rate_detail_cpu_used,
                               :chargeback_rate_id => @cbr.id,
                               :per_time           => "hourly"
                              )
      cbt = FactoryGirl.create(:chargeback_tier,
                               :chargeback_rate_detail_id => cbrd.id,
                               :start                     => 0,
                               :end                       => Float::INFINITY,
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
                               :end                       => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.cpu_allocated_metric).to eq(@cpu_count * @metric_size)
      expect(subject.cpu_used_metric).to eq(@cpu_usagemhz_rate * @metric_size)
      expect(subject.cpu_metric).to eq(subject.cpu_allocated_metric + subject.cpu_used_metric)

      expect(subject.cpu_allocated_cost).to eq(@cpu_count * @count_hourly_rate * @metric_size)
      expect(subject.cpu_used_cost).to eq(@cpu_usagemhz_rate * @hourly_rate * @metric_size)
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
                               :end                       => Float::INFINITY,
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
                               :end                       => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      expect(subject.memory_allocated_metric).to eq(@memory_available * @metric_size)
      expect(subject.memory_used_metric).to eq(@memory_used * @metric_size)
      expect(subject.memory_metric).to eq(subject.memory_allocated_metric + subject.memory_used_metric)

      expect(subject.memory_allocated_cost).to eq(@memory_available * @hourly_rate * @metric_size)
      expect(subject.memory_used_cost).to eq(@memory_used * @hourly_rate * @metric_size)
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
                               :end                       => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save

      expect(subject.disk_io_used_metric).to eq(@disk_usage_rate * @metric_size)
      expect(subject.disk_io_metric).to eq(subject.disk_io_metric)

      expect(subject.disk_io_used_cost).to eq(@disk_usage_rate * @hourly_rate * @metric_size)
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
                               :end                       => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      expect(subject.net_io_used_metric).to eq(@net_usage_rate * @metric_size)
      expect(subject.net_io_metric).to eq(subject.net_io_metric)

      expect(subject.net_io_used_cost).to eq(@net_usage_rate * @hourly_rate * @metric_size)
      expect(subject.net_io_cost).to eq(subject.net_io_used_cost)
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
                               :end                       => Float::INFINITY,
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
                               :end                       => Float::INFINITY,
                               :fixed_rate                => 0.0,
                               :variable_rate             => @count_hourly_rate.to_s
                              )
      cbrd.chargeback_tiers = [cbt]
      cbrd.save
      expect(subject.storage_allocated_metric).to eq(@vm_allocated_disk_storage.gigabytes * @metric_size)
      expect(subject.storage_used_metric).to eq(@vm_used_disk_storage.gigabytes * @metric_size)
      expect(subject.storage_metric).to eq(subject.storage_allocated_metric + subject.storage_used_metric)

      expect(subject.storage_allocated_cost).to eq(@vm_allocated_disk_storage.gigabytes *
                                                   @count_hourly_rate *
                                                   @metric_size)
      expect(subject.storage_used_cost).to eq(@vm_used_disk_storage.gigabytes * @count_hourly_rate * @metric_size)
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
end
