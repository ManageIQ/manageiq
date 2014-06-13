require "spec_helper"

describe EmsCluster::CapacityPlanning do
  before(:each) do
    config = VMDB::Config.new('capacity').config
    EmsCluster.stub(:capacity_settings).and_return(config.deep_clone)
    @cluster = FactoryGirl.create(:ems_cluster)
  end

  it "virtual columns" do
    EmsCluster::CAPACITY_PROFILES.each do |profile|
      prefix = "capacity_profile_#{profile}"
      EmsCluster::CAPACITY_RESOURCES.each do |resource|
        EmsCluster.should have_virtual_column "#{prefix}_#{resource}_method",              :string
        EmsCluster.should have_virtual_column "#{prefix}_#{resource}_commitment_ratio",    :float
        EmsCluster.should have_virtual_column "#{prefix}_#{resource}_minimum",             :float
        EmsCluster.should have_virtual_column "#{prefix}_#{resource}_maximum",             :float

        EmsCluster.should have_virtual_column "#{prefix}_available_host_#{resource}",      :float
        EmsCluster.should have_virtual_column "#{prefix}_remaining_host_#{resource}",      :float
        EmsCluster.should have_virtual_column "#{prefix}_#{resource}_per_vm",              :float
        EmsCluster.should have_virtual_column "#{prefix}_#{resource}_per_vm_with_min_max", :float

        EmsCluster.should have_virtual_column "#{prefix}_remaining_vm_count_based_on_#{resource}", :integer
        EmsCluster.should have_virtual_column "#{prefix}_projected_vm_count_based_on_#{resource}", :integer
      end
      EmsCluster.should have_virtual_column "#{prefix}_remaining_vm_count_based_on_all", :integer
      EmsCluster.should have_virtual_column "#{prefix}_projected_vm_count_based_on_all", :integer
    end
  end

  it "#capacity_profile_method_description" do
    settings_path = [:profile, :"1", :vcpu_method_description]
    @cluster.capacity_profile_method_description(1, :vcpu).should == EmsCluster.capacity_settings.fetch_path(settings_path)
    EmsCluster.capacity_settings.store_path(settings_path, "Test Description")
    @cluster.capacity_profile_method_description(1, :vcpu).should == "Test Description"
  end

  context "#capacity_profile_method" do
    it "with invalid values" do
      EmsCluster.capacity_settings.delete_path(:profile, :"1", :vcpu_method)
      lambda { @cluster.capacity_profile_method(1, :vcpu) }.should raise_error
      EmsCluster.capacity_settings.store_path(:profile, :"1", :vcpu_method, "")
      lambda { @cluster.capacity_profile_method(1, :vcpu) }.should raise_error
      EmsCluster.capacity_settings.store_path(:profile, :"1", :vcpu_method, "invalidresource_average")
      lambda { @cluster.capacity_profile_method(1, :vcpu) }.should raise_error
      EmsCluster.capacity_settings.store_path(:profile, :"1", :vcpu_method, "vcpu_invalidalgorithm")
      lambda { @cluster.capacity_profile_method(1, :vcpu) }.should raise_error
      EmsCluster.capacity_settings.store_path(:profile, :"1", :vcpu_method, "mem_average") # resource does not match profile key
      lambda { @cluster.capacity_profile_method(1, :vcpu) }.should raise_error
    end

    it "with valid values" do
      EmsCluster.capacity_settings.store_path(:profile, :"1", :vcpu_method, "vcpu_high_norm")
      @cluster.capacity_profile_method(1, :vcpu).should   == :vcpu_high_norm

      EmsCluster.capacity_settings.store_path(:profile, :"1", :memory_method, "mem_average")
      @cluster.capacity_profile_method(1, :memory).should == :memory_average
    end

    it "with alternate valid values" do
      EmsCluster.capacity_settings.store_path(:profile, :"1", :vcpu_method, "cpu_average")
      @cluster.capacity_profile_method(1, :vcpu).should   == :vcpu_average

      EmsCluster.capacity_settings.store_path(:profile, :"1", :memory_method, "memory_high_norm")
      @cluster.capacity_profile_method(1, :memory).should == :memory_high_norm
    end
  end

  it "#capacity_profile_minimum" do
    settings_path = [:profile, :"1", :memory_minimum]
    @cluster.capacity_profile_minimum(1, :memory).should be_nil
    EmsCluster.capacity_settings.store_path(settings_path, "123")
    @cluster.capacity_profile_minimum(1, :memory).should == 123
    EmsCluster.capacity_settings.store_path(settings_path, "1.gigabytes")
    @cluster.capacity_profile_minimum(1, :memory).should == 1.gigabytes.to_i
  end

  it "#capacity_profile_maximum" do
    settings_path = [:profile, :"1", :memory_maximum]
    @cluster.capacity_profile_maximum(1, :memory).should be_nil
    EmsCluster.capacity_settings.store_path(settings_path, "123")
    @cluster.capacity_profile_maximum(1, :memory).should == 123
    EmsCluster.capacity_settings.store_path(settings_path, "1.gigabytes")
    @cluster.capacity_profile_maximum(1, :memory).should == 1.gigabytes.to_i
  end

  context "#capacity_commitment_ratio" do
    it "with default settings" do
      @cluster.capacity_commitment_ratio(1, :vcpu).should   == 2.0
      @cluster.capacity_commitment_ratio(1, :memory).should == 1.2
      @cluster.capacity_commitment_ratio(2, :vcpu).should   == 1.0
      @cluster.capacity_commitment_ratio(2, :memory).should == 1.0
    end

    it "with missing settings" do
      EmsCluster.capacity_settings.delete_path(:profile, :"1", :vcpu_commitment_ratio)
      EmsCluster.capacity_settings.delete_path(:profile, :"1", :memory_commitment_ratio)
      EmsCluster.capacity_settings.delete_path(:profile, :"2", :vcpu_commitment_ratio)
      EmsCluster.capacity_settings.delete_path(:profile, :"2", :memory_commitment_ratio)

      @cluster.capacity_commitment_ratio(1, :vcpu).should   == 1.0
      @cluster.capacity_commitment_ratio(1, :memory).should == 1.0
      @cluster.capacity_commitment_ratio(2, :vcpu).should   == 1.0
      @cluster.capacity_commitment_ratio(2, :memory).should == 1.0
    end
  end

  context "#capacity_failover_rule" do
    it "with normal settings" do
      @cluster.capacity_failover_rule.should == "discovered"
    end

    it "with overridden settings" do
      EmsCluster.capacity_settings.store_path(:failover, :rule, "none")
      @cluster.capacity_failover_rule.should == "none"
    end

    it "with missing settings" do
      EmsCluster.capacity_settings.delete_path(:failover, :rule)
      @cluster.capacity_failover_rule.should == "discovered"
    end

    it "with invalid settings" do
      EmsCluster.capacity_settings.store_path(:failover, :rule, "xxx")
      @cluster.capacity_failover_rule.should == "discovered"
    end
  end

  context "#capacity_average_resources_per_vm" do
    it "with normal data" do
      @cluster.stub(:total_vms).and_return(15)
      @cluster.capacity_average_resources_per_vm(35.5).should be_within(0.001).of(2.366)
    end

    it "with missing data" do
      @cluster.stub(:total_vms).and_return(0)
      @cluster.capacity_average_resources_per_vm(35.5).should == 0.0
    end
  end

  context "#capacity_average_resources_per_host" do
    it "with normal data" do
      @cluster.stub(:total_hosts).and_return(15)
      @cluster.capacity_average_resources_per_host(35.5).should be_within(0.001).of(2.366)
    end

    it "with missing data" do
      @cluster.stub(:total_hosts).and_return(0)
      @cluster.capacity_average_resources_per_host(35.5).should == 0.0
    end
  end

  context "#capacity_peak_usage_percentage" do
    it "with normal data" do
      @cluster.stub(:max_cpu_usage_rate_average_high_over_time_period_without_overhead).and_return(11.32)
      @cluster.capacity_peak_usage_percentage(:vcpu).should   == 11.32

      @cluster.stub(:max_mem_usage_absolute_average_high_over_time_period_without_overhead).and_return(35.23)
      @cluster.capacity_peak_usage_percentage(:memory).should == 35.23
    end

    it "with missing data" do
      @cluster.stub(:max_cpu_usage_rate_average_high_over_time_period_without_overhead).and_return(nil)
      @cluster.capacity_peak_usage_percentage(:vcpu).should   == 100.0

      @cluster.stub(:max_mem_usage_absolute_average_high_over_time_period_without_overhead).and_return(nil)
      @cluster.capacity_peak_usage_percentage(:memory).should == 100.0
    end
  end

  context "#capacity_effective_host_resources" do
    it "with effective_resource set" do
      @cluster.stub(:effective_cpu).and_return(31000)
      @cluster.capacity_effective_host_resources(2, :vcpu).should == 31000
    end

    context "with effective_resource not set" do
      before(:each) do
        @cluster.stub(:effective_cpu).and_return(nil)
      end

      it "and normal data" do
        @cluster.stub(:aggregate_cpu_speed).and_return(12345)
        @cluster.capacity_effective_host_resources(2, :vcpu).should == 12345
      end

      it "and missing data" do
        @cluster.stub(:aggregate_cpu_speed).and_return(0)
        @cluster.capacity_effective_host_resources(2, :vcpu).should == 0
      end
    end
  end

  context "#capacity_failover_host_resources" do
    it "with failover rule 'none'" do
      EmsCluster.capacity_settings.store_path(:failover, :rule, "none")
      @cluster.capacity_failover_host_resources(2, :vcpu).should == 0
    end

    context "with failover rule 'discovered'" do
      it "and HA disabled" do
        @cluster.update_attribute(:ha_enabled, false)
        @cluster.capacity_failover_host_resources(2, :vcpu).should == 0
      end

      context "and HA enabled" do
        before(:each) do
          @cluster.update_attribute(:ha_enabled, true)
        end

        it "and no failover hosts" do
          @cluster.stub(:failover_hosts).and_return([])
          @cluster.should_receive(:capacity_failover_host_resources_without_failover_hosts)
          @cluster.capacity_failover_host_resources(2, :vcpu)
        end

        it "and failover hosts" do
          @cluster.stub(:failover_hosts).and_return([1, 2])
          @cluster.should_receive(:capacity_failover_host_resources_with_failover_hosts)
          @cluster.capacity_failover_host_resources(2, :vcpu)
        end
      end
    end
  end

  it "#capacity_failover_host_resources_with_failover_hosts" do
    hosts = [
      FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :logical_cpus => 4), :failover => true),
      FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :logical_cpus => 2), :failover => true),
      FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :logical_cpus => 1), :failover => false)
    ]
    @cluster.hosts << hosts
    @cluster.capacity_failover_host_resources_with_failover_hosts(1, :vcpu).should == 6.0
  end

  it "#capacity_failover_host_resources_without_failover_hosts" do
    hosts = [
      FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :logical_cpus => 4), :failover => false),
      FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :logical_cpus => 2), :failover => false)
    ]
    @cluster.hosts << hosts
    @cluster.capacity_failover_host_resources_without_failover_hosts(1, :vcpu).should == 3.0
  end

  context "#capacity_used_host_resources" do
    it "with normal data" do
      @cluster.stub(:capacity_available_host_resources).and_return(31000)
      @cluster.stub(:max_cpu_usage_rate_average_high_over_time_period_without_overhead).and_return(11.32)
      @cluster.capacity_used_host_resources(2, :vcpu).should be_within(0.001).of(3509.200)
    end

    it "with missing data" do
      @cluster.stub(:capacity_available_host_resources).and_return(0)
      @cluster.stub(:max_cpu_usage_rate_average_high_over_time_period_without_overhead).and_return(nil)
      @cluster.capacity_used_host_resources(2, :vcpu).should == 0.0

      @cluster.stub(:capacity_available_host_resources).and_return(31000)
      @cluster.capacity_used_host_resources(2, :vcpu).should be_within(0.001).of(31000.000)
    end
  end

  context "#capacity_resources_per_vm" do
    it "with normal data" do
      @cluster.stub(:total_vms).and_return(994)
      @cluster.stub(:capacity_available_host_resources).and_return(31000)
      @cluster.stub(:max_cpu_usage_rate_average_high_over_time_period_without_overhead).and_return(11.32)
      @cluster.capacity_resources_per_vm(2, :vcpu).should be_within(0.001).of(3.530)
    end

    it "with missing data" do
      @cluster.stub(:total_vms).and_return(0)
      @cluster.stub(:capacity_available_host_resources).and_return(0)
      @cluster.stub(:max_cpu_usage_rate_average_high_over_time_period_without_overhead).and_return(nil)
      @cluster.capacity_resources_per_vm(2, :vcpu).should == 0.0

      @cluster.stub(:total_vms).and_return(994)
      @cluster.capacity_resources_per_vm(2, :vcpu).should == 0.0

      @cluster.stub(:capacity_available_host_resources).and_return(31000)
      @cluster.capacity_resources_per_vm(2, :vcpu).should be_within(0.001).of(31.187)
    end
  end

  context "#capacity_resources_per_vm_with_min_max" do
    before(:each) do
      @cluster.stub(:capacity_resources_per_vm).and_return(3.530)
    end

    it "with neither min nor max" do
      @cluster.capacity_resources_per_vm_with_min_max(2, :vcpu).should == 3.530
    end

    context "with min only" do
      it "and min < expected" do
        EmsCluster.capacity_settings.store_path(:profile, :"2", :vcpu_minimum, 1.0)
        @cluster.capacity_resources_per_vm_with_min_max(2, :vcpu).should == 3.530
      end

      it "and expected < min" do
        EmsCluster.capacity_settings.store_path(:profile, :"2", :vcpu_minimum, 4.0)
        @cluster.capacity_resources_per_vm_with_min_max(2, :vcpu).should == 4.0
      end
    end

    context "with max only" do
      it "and max < expected" do
        EmsCluster.capacity_settings.store_path(:profile, :"2", :vcpu_maximum, 1.0)
        @cluster.capacity_resources_per_vm_with_min_max(2, :vcpu).should == 1.0
      end

      it "and expected < max" do
        EmsCluster.capacity_settings.store_path(:profile, :"2", :vcpu_maximum, 4.0)
        @cluster.capacity_resources_per_vm_with_min_max(2, :vcpu).should == 3.530
      end
    end

    context "with min and max" do
      it "and min < max < expected" do
        EmsCluster.capacity_settings.store_path(:profile, :"2", :vcpu_minimum, 0.1)
        EmsCluster.capacity_settings.store_path(:profile, :"2", :vcpu_maximum, 1.0)
        @cluster.capacity_resources_per_vm_with_min_max(2, :vcpu).should == 1.0
      end

      it "and min < expected < max" do
        EmsCluster.capacity_settings.store_path(:profile, :"2", :vcpu_minimum, 1.0)
        EmsCluster.capacity_settings.store_path(:profile, :"2", :vcpu_maximum, 4.0)
        @cluster.capacity_resources_per_vm_with_min_max(2, :vcpu).should == 3.530
      end

      it "and expected < min < max" do
        EmsCluster.capacity_settings.store_path(:profile, :"2", :vcpu_minimum, 4.0)
        EmsCluster.capacity_settings.store_path(:profile, :"2", :vcpu_maximum, 5.0)
        @cluster.capacity_resources_per_vm_with_min_max(2, :vcpu).should == 4.0
      end
    end
  end

  it "#capacity_remaining_vm_count" do
    @cluster.update_attribute(:ha_enabled, false)
    @cluster.stub(:total_vms).and_return(994)
    @cluster.stub(:effective_cpu).and_return(31000)
    @cluster.stub(:max_cpu_usage_rate_average_high_over_time_period_without_overhead).and_return(11.32)
    @cluster.capacity_remaining_vm_count(2, :vcpu).should == 7786
  end

  it "#capacity_remaining_vm_count_based_on_all" do
    @cluster.stub(:capacity_remaining_vm_count).with(1, :vcpu).and_return(10)
    @cluster.stub(:capacity_remaining_vm_count).with(1, :memory).and_return(3)
    @cluster.capacity_remaining_vm_count_based_on_all(1).should == 3

    @cluster.stub(:capacity_remaining_vm_count).with(1, :vcpu).and_return(3)
    @cluster.stub(:capacity_remaining_vm_count).with(1, :memory).and_return(10)
    @cluster.capacity_remaining_vm_count_based_on_all(1).should == 3

    @cluster.stub(:capacity_remaining_vm_count).with(1, :vcpu).and_return(-4)
    @cluster.stub(:capacity_remaining_vm_count).with(1, :memory).and_return(10)
    @cluster.capacity_remaining_vm_count_based_on_all(1).should == -4

    @cluster.stub(:capacity_remaining_vm_count).with(1, :vcpu).and_return(10)
    @cluster.stub(:capacity_remaining_vm_count).with(1, :memory).and_return(-4)
    @cluster.capacity_remaining_vm_count_based_on_all(1).should == -4
  end

  it "#capacity_projected_vm_count" do
    @cluster.stub(:total_vms).and_return(3)
    @cluster.stub(:capacity_remaining_vm_count).with(1, :vcpu).and_return(10)
    @cluster.capacity_projected_vm_count(1, :vcpu).should == 13

    @cluster.stub(:total_vms).and_return(10)
    @cluster.stub(:capacity_remaining_vm_count).with(1, :vcpu).and_return(-3)
    @cluster.capacity_projected_vm_count(1, :vcpu).should == 7
  end

  it "#capacity_projected_vm_count_based_on_all" do
    @cluster.stub(:capacity_projected_vm_count).with(1, :vcpu).and_return(10)
    @cluster.stub(:capacity_projected_vm_count).with(1, :memory).and_return(3)
    @cluster.capacity_projected_vm_count_based_on_all(1).should == 3

    @cluster.stub(:capacity_projected_vm_count).with(1, :vcpu).and_return(3)
    @cluster.stub(:capacity_projected_vm_count).with(1, :memory).and_return(10)
    @cluster.capacity_projected_vm_count_based_on_all(1).should == 3
  end
end
