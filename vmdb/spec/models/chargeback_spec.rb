require "spec_helper"

describe Chargeback do
  before do
    MiqRegion.seed
    ChargebackRate.seed

    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_vmware)
    cat = FactoryGirl.create(:classification, :description => "Environment", :name => "environment", :single_value => true, :show => true)
    c = FactoryGirl.create(:classification, :name=>"prod", :description=>"Production", :parent_id => cat.id)
    @tag = Tag.find_by_name("/managed/environment/prod")

    @vm1 = FactoryGirl.create(:vm_vmware, :name => "test_vm")
    @vm1.tag_with(@tag.name, :ns => '*')

    @host1   = FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :memory_cpu => 8124, :logical_cpus => 1, :cpu_speed => 9576), :vms => [@vm1])
    @storage = FactoryGirl.create(:storage_target_vmware)
    @host1.storages << @storage

    @ems_cluster = FactoryGirl.create(:ems_cluster, :ext_management_system => @ems)
    @ems_cluster.hosts << @host1

    @cbr = FactoryGirl.create(:chargeback_rate, :rate_type => "compute")
    temp = { :cb_rate => @cbr, :tag => [c, "vm"] }
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
                :ext_options         => { :tz => "Pacific Time (US & Canada)" }
                }

    Timecop.travel(Time.parse("2012-09-01 00:00:00 UTC"))
  end

  after do
    Timecop.return
  end

  context "Daily" do
    before  do
      @options[:interval] = "daily"

      ["2012-08-31T07:00:00Z", "2012-08-31T08:00:00Z", "2012-08-31T09:00:00Z", "2012-08-31T10:00:00Z"].each do |t|
        @vm1.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                                                   :timestamp                  => t,
                                                   :cpu_usagemhz_rate_average  => @cpu_usagemhz_rate,
                                                   :derived_vm_numvcpus        => @cpu_count,
                                                   :derived_memory_available   => @memory_available,
                                                   :derived_memory_used        => @memory_used,
                                                   :disk_usage_rate_average    => @disk_usage_rate,
                                                   :net_usage_rate_average     => @net_usage_rate,
                                                   :derived_vm_used_disk_storage      => @vm_used_disk_storage.gigabytes,
                                                   :derived_vm_allocated_disk_storage => @vm_allocated_disk_storage.gigabytes,
                                                   :tag_names                  => "environment/prod",
                                                   :parent_host_id             => @host1.id,
                                                   :parent_ems_cluster_id      => @ems_cluster.id,
                                                   :parent_ems_id              => @ems.id,
                                                   :parent_storage_id          => @storage.id,
                                                   :resource_name              => @vm1.name,
                                                 )
      end
      @metric_size = @vm1.metric_rollups.size
    end

    subject { Chargeback.build_results_for_report_chargeback(@options).first.first }

    it "cpu" do
      FactoryGirl.create(:chargeback_rate_detail_cpu_used,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @hourly_rate.to_s,
                        )
      FactoryGirl.create(:chargeback_rate_detail_cpu_allocated,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @count_hourly_rate.to_s,
                        )

      subject.cpu_allocated_metric.should  == @cpu_count * @metric_size
      subject.cpu_used_metric.should       == @cpu_usagemhz_rate * @metric_size
      subject.cpu_metric.should            == subject.cpu_allocated_metric + subject.cpu_used_metric

      subject.cpu_allocated_cost.should    == @cpu_count * @count_hourly_rate * @metric_size
      subject.cpu_used_cost.should         == @cpu_usagemhz_rate * @hourly_rate * @metric_size
      subject.cpu_cost.should              == subject.cpu_allocated_cost + subject.cpu_used_cost
    end

    it "memory" do
      FactoryGirl.create(:chargeback_rate_detail_memory_allocated,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @hourly_rate.to_s,
                        )
      FactoryGirl.create(:chargeback_rate_detail_memory_used,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @hourly_rate.to_s,
                        )

      subject.memory_allocated_metric.should  == @memory_available * @metric_size
      subject.memory_used_metric.should       == @memory_used * @metric_size
      subject.memory_metric.should            == subject.memory_allocated_metric + subject.memory_used_metric

      subject.memory_allocated_cost.should == @memory_available * @hourly_rate * @metric_size
      subject.memory_used_cost.should      == @memory_used * @hourly_rate * @metric_size
      subject.memory_cost.should           == subject.memory_allocated_cost + subject.memory_used_cost
    end

    it "disk io" do
      FactoryGirl.create(:chargeback_rate_detail_disk_io_used,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @hourly_rate.to_s,
                        )

      subject.disk_io_used_metric.should == @disk_usage_rate * @metric_size
      subject.disk_io_metric.should      == subject.disk_io_metric

      subject.disk_io_used_cost.should   == @disk_usage_rate * @hourly_rate * @metric_size
      subject.disk_io_cost.should        == subject.disk_io_used_cost
    end

    it "net io" do
      FactoryGirl.create(:chargeback_rate_detail_net_io_used,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @hourly_rate.to_s,
                        )

      subject.net_io_used_metric.should == @net_usage_rate * @metric_size
      subject.net_io_metric.should      == subject.net_io_metric

      subject.net_io_used_cost.should   == @net_usage_rate * @hourly_rate * @metric_size
      subject.net_io_cost.should        == subject.net_io_used_cost
    end

    it "storage" do
      FactoryGirl.create(:chargeback_rate_detail_storage_used,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @count_hourly_rate.to_s,
                        )
      FactoryGirl.create(:chargeback_rate_detail_storage_allocated,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @count_hourly_rate.to_s,
                        )

      subject.storage_allocated_metric.should  == @vm_allocated_disk_storage.gigabytes * @metric_size
      subject.storage_used_metric.should       == @vm_used_disk_storage.gigabytes * @metric_size
      subject.storage_metric.should            == subject.storage_allocated_metric + subject.storage_used_metric

      subject.storage_allocated_cost.should == @vm_allocated_disk_storage * @count_hourly_rate * @metric_size
      subject.storage_used_cost.should      == @vm_used_disk_storage * @count_hourly_rate * @metric_size
      subject.storage_cost.should           == subject.storage_allocated_cost + subject.storage_used_cost
    end
  end

  context "Monthly" do
    before  do
      @options[:interval] = "monthly"

      tz = Metric::Helper.get_time_zone(@options[:ext_options])
      ts = Time.now.in_time_zone(tz)
      time     = ts.beginning_of_month.utc
      end_time = ts.end_of_month.utc

      while time < end_time do
        @vm1.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                                                   :timestamp                  => time,
                                                   :cpu_usagemhz_rate_average  => @cpu_usagemhz_rate,
                                                   :derived_vm_numvcpus        => @cpu_count,
                                                   :derived_memory_available   => @memory_available,
                                                   :derived_memory_used        => @memory_used,
                                                   :disk_usage_rate_average    => @disk_usage_rate,
                                                   :net_usage_rate_average     => @net_usage_rate,
                                                   :derived_vm_used_disk_storage      => @vm_used_disk_storage.gigabytes,
                                                   :derived_vm_allocated_disk_storage => @vm_allocated_disk_storage.gigabytes,
                                                   :tag_names                  => "environment/prod",
                                                   :parent_host_id             => @host1.id,
                                                   :parent_ems_cluster_id      => @ems_cluster.id,
                                                   :parent_ems_id              => @ems.id,
                                                   :parent_storage_id          => @storage.id,
                                                   :resource_name              => @vm1.name,
                                                 )
        time += 12.hour
      end
      @metric_size = @vm1.metric_rollups.size
    end

    subject { Chargeback.build_results_for_report_chargeback(@options).first.first }

    it "cpu" do
      FactoryGirl.create(:chargeback_rate_detail_cpu_used,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @hourly_rate.to_s,
                        )
      FactoryGirl.create(:chargeback_rate_detail_cpu_allocated,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @count_hourly_rate.to_s,
                        )

      subject.cpu_allocated_metric.should  == @cpu_count * @metric_size
      subject.cpu_used_metric.should       == @cpu_usagemhz_rate * @metric_size
      subject.cpu_metric.should            == subject.cpu_allocated_metric + subject.cpu_used_metric

      subject.cpu_allocated_cost.should    == @cpu_count * @count_hourly_rate * @metric_size
      subject.cpu_used_cost.should         == @cpu_usagemhz_rate * @hourly_rate * @metric_size
      subject.cpu_cost.should              == subject.cpu_allocated_cost + subject.cpu_used_cost
    end

    it "memory" do
      FactoryGirl.create(:chargeback_rate_detail_memory_allocated,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @hourly_rate.to_s,
                        )
      FactoryGirl.create(:chargeback_rate_detail_memory_used,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @hourly_rate.to_s,
                        )

      subject.memory_allocated_metric.should  == @memory_available * @metric_size
      subject.memory_used_metric.should       == @memory_used * @metric_size
      subject.memory_metric.should            == subject.memory_allocated_metric + subject.memory_used_metric

      subject.memory_allocated_cost.should == @memory_available * @hourly_rate * @metric_size
      subject.memory_used_cost.should      == @memory_used * @hourly_rate * @metric_size
      subject.memory_cost.should           == subject.memory_allocated_cost + subject.memory_used_cost
    end

    it "disk io" do
      FactoryGirl.create(:chargeback_rate_detail_disk_io_used,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @hourly_rate.to_s,
                        )

      subject.disk_io_used_metric.should == @disk_usage_rate * @metric_size
      subject.disk_io_metric.should      == subject.disk_io_metric

      subject.disk_io_used_cost.should   == @disk_usage_rate * @hourly_rate * @metric_size
      subject.disk_io_cost.should        == subject.disk_io_used_cost
    end

    it "net io" do
      FactoryGirl.create(:chargeback_rate_detail_net_io_used,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @hourly_rate.to_s,
                        )

      subject.net_io_used_metric.should == @net_usage_rate * @metric_size
      subject.net_io_metric.should      == subject.net_io_metric

      subject.net_io_used_cost.should   == @net_usage_rate * @hourly_rate * @metric_size
      subject.net_io_cost.should        == subject.net_io_used_cost
    end

    it "storage" do
      FactoryGirl.create(:chargeback_rate_detail_storage_used,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @count_hourly_rate.to_s,
                        )
      FactoryGirl.create(:chargeback_rate_detail_storage_allocated,
                         :chargeback_rate_id => @cbr.id,
                         :per_time           => "hourly",
                         :rate               => @count_hourly_rate.to_s,
                        )

      subject.storage_allocated_metric.should  == @vm_allocated_disk_storage.gigabytes * @metric_size
      subject.storage_used_metric.should       == @vm_used_disk_storage.gigabytes * @metric_size
      subject.storage_metric.should            == subject.storage_allocated_metric + subject.storage_used_metric

      subject.storage_allocated_cost.should == @vm_allocated_disk_storage * @count_hourly_rate * @metric_size
      subject.storage_used_cost.should      == @vm_used_disk_storage * @count_hourly_rate * @metric_size
      subject.storage_cost.should           == subject.storage_allocated_cost + subject.storage_used_cost
    end

    context "by owner" do
      before do
        @user = FactoryGirl.create(:user, :name => 'Test VM Owner',  :userid => 'test_user')
        @vm1.update_attribute(:evm_owner, @user)

        @options = { :interval_size => 4,
                     :owner         => @user.userid,
                     :ext_options   => { :tz => "Eastern Time (US & Canada)", }
                   }
      end

      it "valid" do
        subject.owner_name.should == @user.name
      end

      it "not exist" do
        @user.delete
        lambda { subject }.should raise_error(MiqException::Error, "Unable to find user '#{@user.userid}'")
      end
    end
  end
end
