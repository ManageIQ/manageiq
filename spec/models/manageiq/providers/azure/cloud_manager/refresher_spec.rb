require "spec_helper"
require 'azure-armrest'

describe ManageIQ::Providers::Azure::CloudManager do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_azure, :zone => zone, :provider_region => "eastus")
    cred = {
      :userid   => "f895b5ef-3bb5-4366-8ce5-123456789012",
      :password => "5YcZ1lwRmNPWgo82X%2F1l97Fe4VaBGi%2B123456789012"
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
      assert_specific_cloud_network
      assert_specific_flavor
      assert_specific_vm_powered_on
      assert_specific_vm_powered_off
      assert_specific_template
      assert_specific_orchestration_template
      assert_specific_orchestration_stack
    end
  end

  def assert_table_counts
    ExtManagementSystem.count.should eql(1)
    Flavor.count.should eql(33)
    AvailabilityZone.count.should eql(1)
    VmOrTemplate.count.should eql(13)
    Vm.count.should eql(9)
    MiqTemplate.count.should eql(4)
    Disk.count.should eql(11)
    GuestDevice.count.should eql(0)
    Hardware.count.should eql(13)
    Network.count.should eql(15)
    OperatingSystem.count.should eql(9)
    Relationship.count.should eql(0)
    MiqQueue.count.should eql(13)
    OrchestrationTemplate.count.should eql(3)
    OrchestrationStack.count.should eql(7)
    OrchestrationStackParameter.count.should eql(72)
    OrchestrationStackOutput.count.should eql(5)
    OrchestrationStackResource.count.should eql(32)
  end

  def assert_ems
    @ems.should have_attributes(
      :api_version => nil,
      :uid_ems     => "a50f9983-d1a2-4a8d-be7d-123456789012"
    )
    @ems.flavors.size.should eql(33)
    @ems.availability_zones.size.should eql(1)
    @ems.vms_and_templates.size.should eql(13)
    @ems.vms.size.should eql(9)
    @ems.miq_templates.size.should eq(4)

    @ems.orchestration_stacks.size.should eql(7)
    @ems.direct_orchestration_stacks.size.should eql(6)
  end

  def assert_specific_flavor
    @flavor = ManageIQ::Providers::Azure::CloudManager::Flavor.where(:name => "Standard_A0").first
    @flavor.should have_attributes(
      :name                     => "Standard_A0",
      :description              => nil,
      :enabled                  => true,
      :cpus                     => 1,
      :cpu_cores                => 1,
      :memory                   => 768,
      :supports_32_bit          => nil,
      :supports_64_bit          => nil,
      :supports_hvm             => nil,
      :supports_paravirtual     => nil,
      :block_storage_based_only => nil,
      :root_disk_size           => 1023.megabytes,
      :swap_disk_size           => 20.megabytes
    )

    @flavor.ext_management_system.should == @ems
  end

  def assert_specific_az
    @az = ManageIQ::Providers::Azure::CloudManager::AvailabilityZone.first
    @az.should have_attributes(
      :name => @ems.name,
    )
  end

  def assert_specific_cloud_network
    @cn = CloudNetwork.where(:name => "Chef-Prod").first
    @cn.should have_attributes(
      :name    => "Chef-Prod",
      :ems_ref => "/subscriptions/462f2af8-e67e-40c6-9fbf-02824d1dd485"\
                  "/resourceGroups/Chef-Prod/providers/Microsoft.Network"\
                  "/virtualNetworks/Chef-Prod",
      :cidr    => "10.2.0.0/16",
      :status  => nil,
      :enabled => true
    )

    @cn.cloud_subnets.size.should eq(1)
    @subnet = @cn.cloud_subnets.where(:name => "default").first
    @subnet.should have_attributes(
      :name              => "default",
      :ems_ref           => "/subscriptions/462f2af8-e67e-40c6-9fbf-02824d1dd485"\
                             "/resourceGroups/Chef-Prod/providers/Microsoft.Network"\
                             "/virtualNetworks/Chef-Prod/subnets/default",
      :cidr              => "10.2.0.0/24",
      :availability_zone => @az

    )
  end

  def assert_specific_vm_powered_on
    v = ManageIQ::Providers::Azure::CloudManager::Vm.where(:name => "Chef-Prod", :raw_power_state => "VM running").first
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\chef-prod"\
                                "\\microsoft.compute/virtualmachines\\Chef-Prod",
      :ems_ref_obj           => nil,
      :uid_ems               => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\chef-prod"\
                                "\\microsoft.compute/virtualmachines\\Chef-Prod",
      :vendor                => "Microsoft",
      :power_state           => "on",
      :location              => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\chef-prod"\
                                "\\microsoft.compute/virtualmachines\\Chef-Prod",
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
    v.operating_system.product_name.should eql("chef-server chefbyol")
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
      :cpu_sockets         => 1,
      :memory_mb           => 768,
      :disk_capacity       => 1043.megabyte,
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
      :ipaddress   => "40.76.199.78",
      :hostname    => "ipconfig1"
    )
    network = v.hardware.networks.where(:description => "private").first
    network.should have_attributes(
      :description => "private",
      :ipaddress   => "10.2.0.4",
      :hostname    => "ipconfig1"
    )
  end

  def assert_specific_vm_powered_off
    v = ManageIQ::Providers::Azure::CloudManager::Vm.where(
      :name            => "MIQ2",
      :raw_power_state => "VM deallocated").first
    az1 = ManageIQ::Providers::Azure::CloudManager::AvailabilityZone.first

    assert_specific_vm_powered_off_attributes(v)

    v.ext_management_system.should eql(@ems)
    v.availability_zone.should eql(az1)
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
      :ems_ref               => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\computevms\\"\
                                "microsoft.compute/virtualmachines\\MIQ2",
      :ems_ref_obj           => nil,
      :uid_ems               => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\computevms\\"\
                                "microsoft.compute/virtualmachines\\MIQ2",
      :vendor                => "Microsoft",
      :power_state           => "off",
      :location              => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\computevms\\"\
                                "microsoft.compute/virtualmachines\\MIQ2",
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
      :cpu_sockets        => 1,
      :memory_mb          => 768,
      :disk_capacity      => 1043.megabytes,
      :bitness            => nil
    )

    v.hardware.disks.size.should eql(1)
    v.hardware.guest_devices.size.should eql(0)
    v.hardware.nics.size.should eql(0)
    v.hardware.networks.size.should eql(2)
  end

  def assert_specific_template
    name      = "Images/postgres-cont/postgres-osDisk"
    @template = ManageIQ::Providers::Azure::CloudManager::Template.where(:name => name).first
    @template.should have_attributes(
      :template              => true,
      :ems_ref               => "https://chefprod5120.blob.core.windows.net/system/"\
                                "Microsoft.Compute/Images/postgres-cont/"\
                                "postgres-osDisk.fcf3dcec-fb8d-49f5-9d8c-b15edcff704c.vhd",
      :ems_ref_obj           => nil,
      :uid_ems               => "https://chefprod5120.blob.core.windows.net/system/"\
                                "Microsoft.Compute/Images/postgres-cont/"\
                                "postgres-osDisk.fcf3dcec-fb8d-49f5-9d8c-b15edcff704c.vhd",
      :vendor                => "Microsoft",
      :power_state           => "never",
      :location              => "eastus",
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

    @template.ext_management_system.should eq(@ems)
    @template.operating_system.should eq(nil)
    @template.custom_attributes.size.should eq(0)
    @template.snapshots.size.should eq(0)

    @template.hardware.should have_attributes(
      :guest_os            => "Windows",
      :guest_os_full_name  => nil,
      :bios                => nil,
      :annotation          => nil,
      :memory_mb           => nil,
      :disk_capacity       => nil,
      :bitness             => 64,
      :virtualization_type => nil,
      :root_device_type    => nil
    )

    @template.hardware.disks.size.should eq(0)
    @template.hardware.guest_devices.size.should eq(0)
    @template.hardware.nics.size.should eq(0)
    @template.hardware.networks.size.should eq(0)
  end

  def assert_specific_orchestration_template
    @orch_template = OrchestrationTemplateAzure.where(:name => "spec-deployment1-dont-delete").first
    @orch_template.should have_attributes(
      :md5 => "83c7f9914808a5ca7c000477a6daa7df"
    )
    @orch_template.description.should eql('contentVersion: 1.0.0.0')
    @orch_template.content.should start_with("{\n  \"$schema\": \"http://schema.management.azure.com"\
      "/schemas/2015-01-01/deploymentTemplate.json\"")
  end

  def assert_specific_orchestration_stack
    @orch_stack = ManageIQ::Providers::Azure::CloudManager::OrchestrationStack.where(
      :name => "spec-deployment1-dont-delete").first
    @orch_stack.should have_attributes(
      :status         => "Succeeded",
      :description    => 'spec-deployment1-dont-delete',
      :resource_group => 'ComputeVMs',
      :ems_ref        => '/subscriptions/462f2af8-e67e-40c6-9fbf-02824d1dd485/resourceGroups'\
                         '/ComputeVMs/deployments/spec-deployment1-dont-delete',
    )

    assert_specific_orchestration_stack_parameters
    assert_specific_orchestration_stack_resources
    assert_specific_orchestration_stack_outputs
    assert_specific_orchestration_stack_associations
  end

  def assert_specific_orchestration_stack_parameters
    parameters = @orch_stack.parameters.order("ems_ref")
    parameters.should have(13).items

    # assert one of the parameter models
    parameters[1].should have_attributes(
      :name    => "adminUsername",
      :value   => "serveradmin",
      :ems_ref => '/subscriptions/462f2af8-e67e-40c6-9fbf-02824d1dd485/resourceGroups'\
                  '/ComputeVMs/deployments/spec-deployment1-dont-delete\adminUsername'
    )
  end

  def assert_specific_orchestration_stack_resources
    resources = @orch_stack.resources.order("ems_ref")
    resources.should have(9).items

    # assert one of the resource models
    resources.first.should have_attributes(
      :name                   => "myAvSet",
      :logical_resource       => "myAvSet",
      :physical_resource      => "6543c69e-1c83-47d1-96a6-d08d612fea76",
      :resource_category      => "Microsoft.Compute/availabilitySets",
      :resource_status        => "Succeeded",
      :resource_status_reason => "OK",
      :ems_ref                => '/subscriptions/462f2af8-e67e-40c6-9fbf-02824d1dd485/resourceGroups'\
                                 '/ComputeVMs/providers/Microsoft.Compute/availabilitySets/myAvSet'
    )
  end

  def assert_specific_orchestration_stack_outputs
    outputs = ManageIQ::Providers::Azure::CloudManager::OrchestrationStack.where(
      :name => "spec-deployment2-dont-delete").first.outputs
    outputs.should have(1).items
    outputs[0].should have_attributes(
      :key         => "siteUri",
      :value       => "hard-coded output for test",
      :description => "siteUri",
      :ems_ref     => '/subscriptions/462f2af8-e67e-40c6-9fbf-02824d1dd485/resourceGroups'\
                      '/ComputeVMs/deployments/spec-deployment2-dont-delete\siteUri'
    )
  end

  def assert_specific_orchestration_stack_associations
    # orchestration stack belongs to a provider
    @orch_stack.ext_management_system.should eql(@ems)

    # orchestration stack belongs to an orchestration template
    @orch_stack.orchestration_template.should eql(@orch_template)

    # orchestration stack can be nested
    parent_stack = ManageIQ::Providers::Azure::CloudManager::OrchestrationStack.where(
      :name => "spec-deployment2-dont-delete").first
    child_stack = ManageIQ::Providers::Azure::CloudManager::OrchestrationStack.where(
      :name => "spec-nested-deployment-dont-delete").first
    child_stack.parent.should eql(parent_stack)

    # orchestration stack can have vms
    vm = ManageIQ::Providers::Azure::CloudManager::Vm.where(:name => "spec-VM1").first
    vm.orchestration_stack.should eql(@orch_stack)

    # orchestration stack can have cloud networks
    cloud_network = CloudNetwork.where(:name => 'spec-VNET').first
    cloud_network.orchestration_stack.should eql(@orch_stack)
  end
end
