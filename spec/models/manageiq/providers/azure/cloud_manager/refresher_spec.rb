require "spec_helper"
require 'azure-armrest'

describe ManageIQ::Providers::Azure::CloudManager do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_azure, :zone => zone)
    cred = {
      :userid   => "f895b5ef-3bb5-4366-8ce5-123456789012",
      :password => "0+dVmFpJLU0T9gqFWDkWnX9MY3FPb5l1123456789012"
    }
    @ems.authentications << FactoryGirl.create(:authentication, cred)
    @ems.update_attributes(:azure_tenant_id => "a50f9983-d1a2-4a8d-be7d-123456789012")

    # A true thread may fail the test with VCR
    Thread.stub(:new) do |*args, &block|
      block.call(*args)
      Class.new do
        def join; end
      end.new
    end
  end

  it "will perform a full refresh" do
    2.times do # Run twice to verify that a second run with existing data does not change anything
      @ems.reload
      VCR.use_cassette(described_class.name.underscore, :allow_unused_http_interactions => true) do
        EmsRefresh.refresh(@ems)
      end
      @ems.reload

      assert_table_counts
      assert_ems
      assert_specific_az
      assert_specific_flavor
      assert_specific_vm_powered_on
      assert_specific_vm_powered_off
    end
  end

  def assert_table_counts
    ExtManagementSystem.count.should eql(1)
    Flavor.count.should eql(41)
    AvailabilityZone.count.should eql(2)
    VmOrTemplate.count.should eql(5)
    Vm.count.should eql(5)
    Disk.count.should eql(7)
    GuestDevice.count.should eql(0)
    Hardware.count.should eql(5)
    Network.count.should eql(10)
    OperatingSystem.count.should eql(5)
    Relationship.count.should eql(0)
    MiqQueue.count.should eql(5)
  end

  def assert_ems
    @ems.should have_attributes(
      :api_version => nil,
      :uid_ems     => "a50f9983-d1a2-4a8d-be7d-123456789012"
    )
    @ems.flavors.size.should eql(41)
    @ems.availability_zones.size.should eql(2)
    @ems.vms_and_templates.size.should eql(5)
    @ems.vms.size.should eql(5)
  end

  def assert_specific_flavor
    @flavor = ManageIQ::Providers::Azure::CloudManager::Flavor.where(:name => "Standard_A1").first
    @flavor.should have_attributes(
      :name                     => "Standard_A1",
      :description              => nil,
      :enabled                  => true,
      :cpus                     => 1,
      :cpu_cores                => 1,
      :memory                   => 1792,
      :supports_32_bit          => nil,
      :supports_64_bit          => nil,
      :supports_hvm             => nil,
      :supports_paravirtual     => nil,
      :block_storage_based_only => nil,
    )

    @flavor.ext_management_system.should == @ems
  end

  def assert_specific_az
    @az = ManageIQ::Providers::Azure::CloudManager::AvailabilityZone.where(:name => "AvailabilitySet1").first
    @az.should have_attributes(
      :name => "AvailabilitySet1",
    )
  end

  def assert_specific_vm_powered_on
    v = ManageIQ::Providers::Azure::CloudManager::Vm.where(:name => "ERP", :raw_power_state => "VM running").first
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\ComputeVMs\\ERP",
      :ems_ref_obj           => nil,
      :uid_ems               => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\ComputeVMs\\ERP",
      :vendor                => "Microsoft",
      :power_state           => "on",
      :location              => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\ComputeVMs\\ERP",
      :tools_status          => nil,
      :boot_time             => nil,
      :standby_action        => nil,
      :connection_state      => nil,
      :cpu_affinity          => nil,
      :memory_reserve        => nil,
      :memory_reserve_expand => nil,
      :memory_limit          => nil,
      :memory_shares         => nil,
      :memory_shares_level   => nil,
      :cpu_reserve           => nil,
      :cpu_reserve_expand    => nil,
      :cpu_limit             => nil,
      :cpu_shares            => nil,
      :cpu_shares_level      => nil
    )

    v.ext_management_system.should eql(@ems)
    v.availability_zone.should eql(@az)
    v.flavor.should eql(@flavor)
    v.operating_system.product_name.should eql("UbuntuServer 14.04.3 LTS")
    v.custom_attributes.size.should eql(0)
    v.snapshots.size.should eql(0)

    assert_specific_vm_powered_on_hardware(v)
  end

  def assert_specific_vm_powered_on_hardware(v)
    v.hardware.should have_attributes(
      :guest_os            => nil,
      :guest_os_full_name  => nil,
      :bios                => nil,
      :annotation          => nil,
      :numvcpus            => 1,
      :memory_cpu          => 1792, # MB
      :disk_capacity       => 1_072_764_928,
      :bitness             => nil,
      :virtualization_type => nil
    )

    v.hardware.disks.size.should eql(1) # TODO: Change to a flavor that has disks
    v.hardware.guest_devices.size.should eql(0)
    v.hardware.nics.size.should eql(0)

    assert_specific_vm_powered_on_hardware_networks(v)
  end

  def assert_specific_vm_powered_on_hardware_networks(v)
    v.hardware.networks.size.should eql(2)
    network = v.hardware.networks.where(:description => "public").first
    network.should have_attributes(
      :description => "public",
      :ipaddress   => "137.135.124.168",
      :hostname    => "ipconfig1"
    )
    network = v.hardware.networks.where(:description => "private").first
    network.should have_attributes(
      :description => "private",
      :ipaddress   => "10.0.0.8",
      :hostname    => "ipconfig1"
    )
  end

  def assert_specific_vm_powered_off
    v = ManageIQ::Providers::Azure::CloudManager::Vm.where(:name => "MIQ2", :raw_power_state => "VM deallocated").first

    assert_specific_vm_powered_off_attributes(v)

    v.ext_management_system.should eql(@ems)
    v.availability_zone.should eql(@az)
    v.floating_ip.should be_nil
    v.cloud_network.should be_nil
    v.cloud_subnet.should be_nil
    v.operating_system.product_name.should eql("UbuntuServer 14.04.3 LTS")
    v.custom_attributes.size.should eql(0)
    v.snapshots.size.should eql(0)

    assert_specific_vm_powered_off_hardware(v)
  end

  def assert_specific_vm_powered_off_attributes(v)
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\ComputeVMs\\MIQ2",
      :ems_ref_obj           => nil,
      :uid_ems               => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\ComputeVMs\\MIQ2",
      :vendor                => "Microsoft",
      :power_state           => "off",
      :location              => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\ComputeVMs\\MIQ2",
      :tools_status          => nil,
      :boot_time             => nil,
      :standby_action        => nil,
      :connection_state      => nil,
      :cpu_affinity          => nil,
      :memory_reserve        => nil,
      :memory_reserve_expand => nil,
      :memory_limit          => nil,
      :memory_shares         => nil,
      :memory_shares_level   => nil,
      :cpu_reserve           => nil,
      :cpu_reserve_expand    => nil,
      :cpu_limit             => nil,
      :cpu_shares            => nil,
      :cpu_shares_level      => nil
    )
  end

  def assert_specific_vm_powered_off_hardware(v)
    v.hardware.should have_attributes(
      :guest_os           => nil,
      :guest_os_full_name => nil,
      :bios               => nil,
      :annotation         => nil,
      :numvcpus           => 1,
      :memory_cpu         => 768, # MB
      :disk_capacity      => 1_072_713_728,
      :bitness            => nil
    )

    v.hardware.disks.size.should eql(1)
    v.hardware.guest_devices.size.should eql(0)
    v.hardware.nics.size.should eql(0)
    v.hardware.networks.size.should eql(2)
  end
end
