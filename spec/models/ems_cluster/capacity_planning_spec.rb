describe EmsCluster::CapacityPlanning do
  before(:each) do
    @cluster = FactoryGirl.create(:ems_cluster)
  end

  it "virtual columns" do
    EmsCluster::CAPACITY_PROFILES.each do |profile|
      prefix = "capacity_profile_#{profile}"
      EmsCluster::CAPACITY_RESOURCES.each do |resource|
        expect(EmsCluster).to have_virtual_column "#{prefix}_#{resource}_method",              :string
        expect(EmsCluster).to have_virtual_column "#{prefix}_#{resource}_commitment_ratio",    :float
        expect(EmsCluster).to have_virtual_column "#{prefix}_#{resource}_minimum",             :float
        expect(EmsCluster).to have_virtual_column "#{prefix}_#{resource}_maximum",             :float

        expect(EmsCluster).to have_virtual_column "#{prefix}_available_host_#{resource}",      :float
        expect(EmsCluster).to have_virtual_column "#{prefix}_remaining_host_#{resource}",      :float
        expect(EmsCluster).to have_virtual_column "#{prefix}_#{resource}_per_vm",              :float
        expect(EmsCluster).to have_virtual_column "#{prefix}_#{resource}_per_vm_with_min_max", :float

        expect(EmsCluster).to have_virtual_column "#{prefix}_remaining_vm_count_based_on_#{resource}", :integer
        expect(EmsCluster).to have_virtual_column "#{prefix}_projected_vm_count_based_on_#{resource}", :integer
      end
      expect(EmsCluster).to have_virtual_column "#{prefix}_remaining_vm_count_based_on_all", :integer
      expect(EmsCluster).to have_virtual_column "#{prefix}_projected_vm_count_based_on_all", :integer
    end
  end

  it "#capacity_profile_method_description" do
    stub_settings(:capacity => {:profile => {'1' => {:vcpu_method_description => "Test Description"}}})
    expect(@cluster.capacity_profile_method_description(1, :vcpu)).to eq("Test Description")
  end

  context "#capacity_profile_method" do
    it "with invalid values" do
      stub_settings(:capacity => {:profile => {'1' => {:vcpu_method => nil}}})
      expect { @cluster.capacity_profile_method(1, :vcpu) }.to raise_error(RuntimeError, /Invalid vcpu_method/)

      stub_settings(:capacity => {:profile => {'1' => {:vcpu_method => "invalidresource_average"}}})
      expect { @cluster.capacity_profile_method(1, :vcpu) }.to raise_error(RuntimeError, /Invalid vcpu_method/)
      # resource does not match profile key
      stub_settings(:capacity => {:profile => {'1' => {:vcpu_method => "mem_average"}}})
      expect { @cluster.capacity_profile_method(1, :vcpu) }.to raise_error(RuntimeError, /Invalid vcpu_method/)
    end

    it "with valid values" do
      stub_settings(:capacity => {:profile => {'1' => {:vcpu_method => "vcpu_high_norm"}}})
      expect(@cluster.capacity_profile_method(1, :vcpu)).to eq(:vcpu_high_norm)

      stub_settings(:capacity => {:profile => {'1' => {:memory_method => "mem_average"}}})
      expect(@cluster.capacity_profile_method(1, :memory)).to eq(:memory_average)
    end

    it "with alternate valid values" do
      stub_settings(:capacity => {:profile => {'1' => {:vcpu_method => "cpu_average"}}})
      expect(@cluster.capacity_profile_method(1, :vcpu)).to eq(:vcpu_average)

      stub_settings(:capacity => {:profile => {'1' => {:memory_method => "memory_high_norm"}}})
      expect(@cluster.capacity_profile_method(1, :memory)).to eq(:memory_high_norm)
    end
  end

  it "#capacity_profile_minimum" do
    stub_settings(:capacity => {:profile => {'1' => {:memory_minimum => 123}}})
    expect(@cluster.capacity_profile_minimum(1, :memory)).to eq(123)

    stub_settings(:capacity => {:profile => {'1' => {:memory_minimum => "1.gigabytes"}}})
    expect(@cluster.capacity_profile_minimum(1, :memory)).to eq(1.gigabytes.to_i)
  end

  it "#capacity_profile_maximum" do
    stub_settings(:capacity => {:profile => {'1' => {:memory_maximum => 123}}})
    expect(@cluster.capacity_profile_maximum(1, :memory)).to eq(123)

    stub_settings(:capacity => {:profile => {'1' => {:memory_maximum => "1.gigabytes"}}})
    expect(@cluster.capacity_profile_maximum(1, :memory)).to eq(1.gigabytes.to_i)
  end

  context "#capacity_commitment_ratio" do
    it "with default settings" do
      expect(@cluster.capacity_commitment_ratio(1, :vcpu)).to eq(2.0)
      expect(@cluster.capacity_commitment_ratio(1, :memory)).to eq(1.2)
      expect(@cluster.capacity_commitment_ratio(2, :vcpu)).to eq(1.0)
      expect(@cluster.capacity_commitment_ratio(2, :memory)).to eq(1.0)
    end

    it "with missing settings" do
      stub_settings(:capacity => {:profile => {}})
      expect(@cluster.capacity_commitment_ratio(1, :vcpu)).to eq(1.0)
      expect(@cluster.capacity_commitment_ratio(1, :memory)).to eq(1.0)
      expect(@cluster.capacity_commitment_ratio(2, :vcpu)).to eq(1.0)
      expect(@cluster.capacity_commitment_ratio(2, :memory)).to eq(1.0)
    end
  end

  context "#capacity_failover_rule" do
    it "with normal settings" do
      expect(@cluster.capacity_failover_rule).to eq("discovered")
    end

    it "with overridden settings" do
      stub_settings(:capacity => {:failover => {:rule => "none"}})
      expect(@cluster.capacity_failover_rule).to eq("none")
    end

    it "with invalid settings" do
      stub_settings(:capacity => {:failover => {:rule => "xxx"}})
      expect(@cluster.capacity_failover_rule).to eq("discovered")
    end
  end

  context "#capacity_average_resources_per_vm" do
    it "with normal data" do
      allow(@cluster).to receive(:total_vms).and_return(15)
      expect(@cluster.capacity_average_resources_per_vm(35.5)).to be_within(0.001).of(2.366)
    end

    it "with missing data" do
      allow(@cluster).to receive(:total_vms).and_return(0)
      expect(@cluster.capacity_average_resources_per_vm(35.5)).to eq(0.0)
    end
  end

  context "#capacity_average_resources_per_host" do
    it "with normal data" do
      allow(@cluster).to receive(:total_hosts).and_return(15)
      expect(@cluster.capacity_average_resources_per_host(35.5)).to be_within(0.001).of(2.366)
    end

    it "with missing data" do
      allow(@cluster).to receive(:total_hosts).and_return(0)
      expect(@cluster.capacity_average_resources_per_host(35.5)).to eq(0.0)
    end
  end

  context "#capacity_peak_usage_percentage" do
    it "with normal data" do
      allow(@cluster).to receive(:max_cpu_usage_rate_average_high_over_time_period_without_overhead).and_return(11.32)
      expect(@cluster.capacity_peak_usage_percentage(:vcpu)).to eq(11.32)

      allow(@cluster)
        .to receive(:max_mem_usage_absolute_average_high_over_time_period_without_overhead)
        .and_return(35.23)
      expect(@cluster.capacity_peak_usage_percentage(:memory)).to eq(35.23)
    end

    it "with missing data" do
      allow(@cluster).to receive(:max_cpu_usage_rate_average_high_over_time_period_without_overhead).and_return(nil)
      expect(@cluster.capacity_peak_usage_percentage(:vcpu)).to eq(100.0)

      allow(@cluster).to receive(:max_mem_usage_absolute_average_high_over_time_period_without_overhead).and_return(nil)
      expect(@cluster.capacity_peak_usage_percentage(:memory)).to eq(100.0)
    end
  end

  context "#capacity_effective_host_resources" do
    it "with effective_resource set" do
      allow(@cluster).to receive(:effective_cpu).and_return(31_000)
      expect(@cluster.capacity_effective_host_resources(2, :vcpu)).to eq(31_000)
    end

    context "with effective_resource not set" do
      before(:each) do
        allow(@cluster).to receive(:effective_cpu).and_return(nil)
      end

      it "and normal data" do
        allow(@cluster).to receive(:aggregate_cpu_speed).and_return(12_345)
        expect(@cluster.capacity_effective_host_resources(2, :vcpu)).to eq(12_345)
      end

      it "and missing data" do
        allow(@cluster).to receive(:aggregate_cpu_speed).and_return(0)
        expect(@cluster.capacity_effective_host_resources(2, :vcpu)).to eq(0)
      end
    end
  end

  context "#capacity_failover_host_resources" do
    it "with failover rule 'none'" do
      stub_settings(:capacity => {:failover => {:rule => "none"}})
      expect(@cluster.capacity_failover_host_resources(2, :vcpu)).to eq(0)
    end

    context "with failover rule 'discovered'" do
      it "and HA disabled" do
        @cluster.update_attribute(:ha_enabled, false)
        expect(@cluster.capacity_failover_host_resources(2, :vcpu)).to eq(0)
      end

      context "and HA enabled" do
        before(:each) do
          @cluster.update_attribute(:ha_enabled, true)
        end

        it "and no failover hosts" do
          allow(@cluster).to receive(:failover_hosts).and_return([])
          expect(@cluster).to receive(:capacity_failover_host_resources_without_failover_hosts)
          @cluster.capacity_failover_host_resources(2, :vcpu)
        end

        it "and failover hosts" do
          allow(@cluster).to receive(:failover_hosts).and_return([1, 2])
          expect(@cluster).to receive(:capacity_failover_host_resources_with_failover_hosts)
          @cluster.capacity_failover_host_resources(2, :vcpu)
        end
      end
    end
  end

  it "#capacity_failover_host_resources_with_failover_hosts" do
    hosts = [
      FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :cpu_total_cores => 4), :failover => true),
      FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :cpu_total_cores => 2), :failover => true),
      FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :cpu_total_cores => 1), :failover => false)
    ]
    @cluster.hosts << hosts
    expect(@cluster.capacity_failover_host_resources_with_failover_hosts(1, :vcpu)).to eq(6.0)
  end

  it "#capacity_failover_host_resources_without_failover_hosts" do
    hosts = [
      FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :cpu_total_cores => 4), :failover => false),
      FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :cpu_total_cores => 2), :failover => false)
    ]
    @cluster.hosts << hosts
    expect(@cluster.capacity_failover_host_resources_without_failover_hosts(1, :vcpu)).to eq(3.0)
  end

  context "#capacity_used_host_resources" do
    it "with normal data" do
      allow(@cluster).to receive(:capacity_available_host_resources).and_return(31_000)
      allow(@cluster).to receive(:max_cpu_usage_rate_average_high_over_time_period_without_overhead).and_return(11.32)
      expect(@cluster.capacity_used_host_resources(2, :vcpu)).to be_within(0.001).of(3_509.200)
    end

    it "with missing data" do
      allow(@cluster).to receive(:capacity_available_host_resources).and_return(0)
      allow(@cluster).to receive(:max_cpu_usage_rate_average_high_over_time_period_without_overhead).and_return(nil)
      expect(@cluster.capacity_used_host_resources(2, :vcpu)).to eq(0.0)

      allow(@cluster).to receive(:capacity_available_host_resources).and_return(31_000)
      expect(@cluster.capacity_used_host_resources(2, :vcpu)).to be_within(0.001).of(31_000.000)
    end
  end

  context "#capacity_resources_per_vm" do
    it "with normal data" do
      allow(@cluster).to receive(:total_vms).and_return(994)
      allow(@cluster).to receive(:capacity_available_host_resources).and_return(31_000)
      allow(@cluster).to receive(:max_cpu_usage_rate_average_high_over_time_period_without_overhead).and_return(11.32)
      expect(@cluster.capacity_resources_per_vm(2, :vcpu)).to be_within(0.001).of(3.530)
    end

    it "with missing data" do
      allow(@cluster).to receive(:total_vms).and_return(0)
      allow(@cluster).to receive(:capacity_available_host_resources).and_return(0)
      allow(@cluster).to receive(:max_cpu_usage_rate_average_high_over_time_period_without_overhead).and_return(nil)
      expect(@cluster.capacity_resources_per_vm(2, :vcpu)).to eq(0.0)

      allow(@cluster).to receive(:total_vms).and_return(994)
      expect(@cluster.capacity_resources_per_vm(2, :vcpu)).to eq(0.0)

      allow(@cluster).to receive(:capacity_available_host_resources).and_return(31_000)
      expect(@cluster.capacity_resources_per_vm(2, :vcpu)).to be_within(0.001).of(31.187)
    end
  end

  context "#capacity_resources_per_vm_with_min_max" do
    before(:each) do
      allow(@cluster).to receive(:capacity_resources_per_vm).and_return(3.530)
    end

    it "with neither min nor max" do
      expect(@cluster.capacity_resources_per_vm_with_min_max(2, :vcpu)).to eq(3.530)
    end

    context "with min only" do
      it "and min < expected" do
        stub_settings(:capacity => {:profile => {'2' => {:vcpu_minimum => 1.0}}})
        expect(@cluster.capacity_resources_per_vm_with_min_max(2, :vcpu)).to eq(3.530)
      end

      it "and expected < min" do
        stub_settings(:capacity => {:profile => {'2' => {:vcpu_minimum => 4.0}}})
        expect(@cluster.capacity_resources_per_vm_with_min_max(2, :vcpu)).to eq(4.0)
      end
    end

    context "with max only" do
      it "and max < expected" do
        stub_settings(:capacity => {:profile => {'2' => {:vcpu_maximum => 1.0}}})
        expect(@cluster.capacity_resources_per_vm_with_min_max(2, :vcpu)).to eq(1.0)
      end

      it "and expected < max" do
        stub_settings(:capacity => {:profile => {'2' => {:vcpu_maximum => 4.0}}})
        expect(@cluster.capacity_resources_per_vm_with_min_max(2, :vcpu)).to eq(3.530)
      end
    end

    context "with min and max" do
      it "and min < max < expected" do
        stub_settings(:capacity => {:profile => {'2' => {:vcpu_minimum => 1.0, :vcpu_maximum => 1.0}}})
        expect(@cluster.capacity_resources_per_vm_with_min_max(2, :vcpu)).to eq(1.0)
      end

      it "and min < expected < max" do
        stub_settings(:capacity => {:profile => {'2' => {:vcpu_minimum => 1.0, :vcpu_maximum => 4.0}}})
        expect(@cluster.capacity_resources_per_vm_with_min_max(2, :vcpu)).to eq(3.530)
      end

      it "and expected < min < max" do
        stub_settings(:capacity => {:profile => {'2' => {:vcpu_minimum => 4.0, :vcpu_maximum => 5.0}}})
        expect(@cluster.capacity_resources_per_vm_with_min_max(2, :vcpu)).to eq(4.0)
      end
    end
  end

  it "#capacity_remaining_vm_count" do
    @cluster.update_attribute(:ha_enabled, false)
    allow(@cluster).to receive(:total_vms).and_return(994)
    allow(@cluster).to receive(:effective_cpu).and_return(31_000)
    allow(@cluster).to receive(:max_cpu_usage_rate_average_high_over_time_period_without_overhead).and_return(11.32)
    expect(@cluster.capacity_remaining_vm_count(2, :vcpu)).to eq(7_786)
  end

  it "#capacity_remaining_vm_count_based_on_all" do
    allow(@cluster).to receive(:capacity_remaining_vm_count).with(1, :vcpu).and_return(10)
    allow(@cluster).to receive(:capacity_remaining_vm_count).with(1, :memory).and_return(3)
    expect(@cluster.capacity_remaining_vm_count_based_on_all(1)).to eq(3)

    allow(@cluster).to receive(:capacity_remaining_vm_count).with(1, :vcpu).and_return(3)
    allow(@cluster).to receive(:capacity_remaining_vm_count).with(1, :memory).and_return(10)
    expect(@cluster.capacity_remaining_vm_count_based_on_all(1)).to eq(3)

    allow(@cluster).to receive(:capacity_remaining_vm_count).with(1, :vcpu).and_return(-4)
    allow(@cluster).to receive(:capacity_remaining_vm_count).with(1, :memory).and_return(10)
    expect(@cluster.capacity_remaining_vm_count_based_on_all(1)).to eq(-4)

    allow(@cluster).to receive(:capacity_remaining_vm_count).with(1, :vcpu).and_return(10)
    allow(@cluster).to receive(:capacity_remaining_vm_count).with(1, :memory).and_return(-4)
    expect(@cluster.capacity_remaining_vm_count_based_on_all(1)).to eq(-4)
  end

  it "#capacity_projected_vm_count" do
    allow(@cluster).to receive(:total_vms).and_return(3)
    allow(@cluster).to receive(:capacity_remaining_vm_count).with(1, :vcpu).and_return(10)
    expect(@cluster.capacity_projected_vm_count(1, :vcpu)).to eq(13)

    allow(@cluster).to receive(:total_vms).and_return(10)
    allow(@cluster).to receive(:capacity_remaining_vm_count).with(1, :vcpu).and_return(-3)
    expect(@cluster.capacity_projected_vm_count(1, :vcpu)).to eq(7)
  end

  it "#capacity_projected_vm_count_based_on_all" do
    allow(@cluster).to receive(:capacity_projected_vm_count).with(1, :vcpu).and_return(10)
    allow(@cluster).to receive(:capacity_projected_vm_count).with(1, :memory).and_return(3)
    expect(@cluster.capacity_projected_vm_count_based_on_all(1)).to eq(3)

    allow(@cluster).to receive(:capacity_projected_vm_count).with(1, :vcpu).and_return(3)
    allow(@cluster).to receive(:capacity_projected_vm_count).with(1, :memory).and_return(10)
    expect(@cluster.capacity_projected_vm_count_based_on_all(1)).to eq(3)
  end
end
