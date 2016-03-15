require 'azure-armrest'

describe ManageIQ::Providers::Azure::CloudManager::Refresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_azure, :zone => zone, :provider_region => "eastus")

    @client_id  = Rails.application.secrets.azure.try(:[], 'client_id') || 'AZURE_CLIENT_ID'
    @client_key = Rails.application.secrets.azure.try(:[], 'client_secret') || 'AZURE_CLIENT_SECRET'
    @tenant_id  = Rails.application.secrets.azure.try(:[], 'tenant_id') || 'AZURE_TENANT_ID'

    cred = {
      :userid   => @client_id,
      :password => @client_key
    }

    @ems.authentications << FactoryGirl.create(:authentication, cred)
    @ems.update_attributes(:azure_tenant_id => @tenant_id)

    # A true thread may fail the test with VCR
    allow(Thread).to receive(:new) do |*args, &block|
      block.call(*args)
      Class.new do
        def join; end
      end.new
    end
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:azure)
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
      assert_specific_disk
      assert_specific_security_group
      assert_specific_vm_powered_on
      assert_specific_vm_powered_off
      assert_specific_template
      assert_specific_orchestration_template
      assert_specific_orchestration_stack
    end
  end

  def assert_table_counts
    expect(ExtManagementSystem.count).to eql(1)
    expect(Flavor.count).to eql(42)
    expect(AvailabilityZone.count).to eql(1)
    expect(VmOrTemplate.count).to eql(17)
    expect(Vm.count).to eql(13)
    expect(MiqTemplate.count).to eql(4)
    expect(Disk.count).to eql(15)
    expect(GuestDevice.count).to eql(0)
    expect(Hardware.count).to eql(17)
    expect(Network.count).to eql(22)
    expect(OperatingSystem.count).to eql(13)
    expect(Relationship.count).to eql(0)
    expect(MiqQueue.count).to eql(17)
    expect(OrchestrationTemplate.count).to eql(2)
    expect(OrchestrationStack.count).to eql(9)
    expect(OrchestrationStackParameter.count).to eql(100)
    expect(OrchestrationStackOutput.count).to eql(9)
    expect(OrchestrationStackResource.count).to eql(44)
    expect(SecurityGroup.count).to eql(11)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :api_version => nil,
      :uid_ems     => @tenant_id
    )
    expect(@ems.flavors.size).to eql(42)
    expect(@ems.availability_zones.size).to eql(1)
    expect(@ems.vms_and_templates.size).to eql(17)
    expect(@ems.vms.size).to eql(13)
    expect(@ems.miq_templates.size).to eq(4)

    expect(@ems.orchestration_stacks.size).to eql(9)
    expect(@ems.direct_orchestration_stacks.size).to eql(8)
  end

  def assert_specific_security_group
    @sg = ManageIQ::Providers::Azure::CloudManager::SecurityGroup.where(:name => "Chef-Prod").first

    expect(@sg).to have_attributes(
      :name        => "Chef-Prod",
      :description => "Chef-Prod-eastus"
    )

    expected_firewall_rules = [
      {:host_protocol => "TCP", :direction => "Inbound", :port => 22,  :end_port => 22,  :source_ip_range => "*"},
      {:host_protocol => "TCP", :direction => "Inbound", :port => 80,  :end_port => 80,  :source_ip_range => "*"},
      {:host_protocol => "TCP", :direction => "Inbound", :port => 443, :end_port => 443, :source_ip_range => "*"}
    ]

    expect(@sg.firewall_rules.size).to eq(3)

    @sg.firewall_rules
      .order(:host_protocol, :direction, :port, :end_port, :source_ip_range, :source_security_group_id)
      .zip(expected_firewall_rules)
      .each do |actual, expected|
        expect(actual).to have_attributes(expected)
      end
  end

  def assert_specific_flavor
    @flavor = ManageIQ::Providers::Azure::CloudManager::Flavor.where(:name => "Basic_A0").first
    expect(@flavor).to have_attributes(
      :name                     => "Basic_A0",
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

    expect(@flavor.ext_management_system).to eq(@ems)
  end

  def assert_specific_az
    @az = ManageIQ::Providers::Azure::CloudManager::AvailabilityZone.first
    expect(@az).to have_attributes(
      :name => @ems.name,
    )
  end

  def assert_specific_cloud_network
    @cn = CloudNetwork.where(:name => "Chef-Prod").first
    expect(@cn).to have_attributes(
      :name    => "Chef-Prod",
      :ems_ref => "/subscriptions/462f2af8-e67e-40c6-9fbf-02824d1dd485"\
                  "/resourceGroups/Chef-Prod/providers/Microsoft.Network"\
                  "/virtualNetworks/Chef-Prod",
      :cidr    => "10.2.0.0/16",
      :status  => nil,
      :enabled => true
    )

    expect(@cn.cloud_subnets.size).to eq(1)
    @subnet = @cn.cloud_subnets.where(:name => "default").first
    expect(@subnet).to have_attributes(
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
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\chef-prod"\
                                "\\microsoft.compute/virtualmachines\\Chef-Prod",
      :ems_ref_obj           => nil,
      :uid_ems               => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\chef-prod"\
                                "\\microsoft.compute/virtualmachines\\Chef-Prod",
      :vendor                => "azure",
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

    expect(v.ext_management_system).to eql(@ems)
    expect(v.availability_zone).to eql(@az)
    expect(v.flavor).to eql(@flavor)
    expect(v.operating_system.product_name).to eql("chef-server chefbyol")
    expect(v.custom_attributes.size).to eql(0)
    expect(v.snapshots.size).to eql(0)

    assert_specific_vm_powered_on_hardware(v)
  end

  def assert_specific_vm_powered_on_hardware(v)
    expect(v.hardware).to have_attributes(
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

    expect(v.hardware.guest_devices.size).to eql(0)
    expect(v.hardware.nics.size).to eql(0)

    assert_specific_hardware_networks(v)
  end

  def assert_specific_hardware_networks(v)
    expect(v.hardware.networks.size).to eql(2)
    network = v.hardware.networks.where(:description => "public").first
    expect(network).to have_attributes(
      :description => "public",
      :ipaddress   => "40.117.35.167",
      :hostname    => "ipconfig1"
    )
    network = v.hardware.networks.where(:description => "private").first
    expect(network).to have_attributes(
      :description => "private",
      :ipaddress   => "10.2.0.4",
      :hostname    => "ipconfig1"
    )
  end

  def assert_specific_disk
    disk = Disk.where(:device_name => "Chef-Prod").first

    expect(disk).to have_attributes(
      :location    => "http://chefprod5120.blob.core.windows.net/vhds/Chef-Prod.vhd",
      :size        => 1023.megabyte
    )
  end

  def assert_specific_vm_powered_off
    v = ManageIQ::Providers::Azure::CloudManager::Vm.where(
      :name            => "MIQ2",
      :raw_power_state => "VM deallocated").first
    az1 = ManageIQ::Providers::Azure::CloudManager::AvailabilityZone.first

    assert_specific_vm_powered_off_attributes(v)

    expect(v.ext_management_system).to eql(@ems)
    expect(v.availability_zone).to eql(az1)
    expect(v.floating_ip).to be_nil
    expect(v.cloud_network).to be_nil
    expect(v.cloud_subnet).to be_nil
    expect(v.operating_system.product_name).to eql("UbuntuServer 14.04.3 LTS")
    expect(v.custom_attributes.size).to eql(0)
    expect(v.snapshots.size).to eql(0)

    assert_specific_vm_powered_off_hardware(v)
  end

  def assert_specific_vm_powered_off_attributes(v)
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\computevms\\"\
                                "microsoft.compute/virtualmachines\\MIQ2",
      :ems_ref_obj           => nil,
      :uid_ems               => "462f2af8-e67e-40c6-9fbf-02824d1dd485\\computevms\\"\
                                "microsoft.compute/virtualmachines\\MIQ2",
      :vendor                => "azure",
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
    expect(v.hardware).to have_attributes(
      :guest_os           => nil,
      :guest_os_full_name => nil,
      :bios               => nil,
      :annotation         => nil,
      :cpu_sockets        => 1,
      :memory_mb          => 768,
      :disk_capacity      => 1043.megabytes,
      :bitness            => nil
    )

    expect(v.hardware.disks.size).to eql(1)
    expect(v.hardware.guest_devices.size).to eql(0)
    expect(v.hardware.nics.size).to eql(0)
    expect(v.hardware.networks.size).to eql(2)
  end

  def assert_specific_template
    name      = "Images/postgres-cont/postgres-osDisk"
    @template = ManageIQ::Providers::Azure::CloudManager::Template.where(:name => name).first
    expect(@template).to have_attributes(
      :template              => true,
      :ems_ref               => "https://chefprod5120.blob.core.windows.net/system/"\
                                "Microsoft.Compute/Images/postgres-cont/"\
                                "postgres-osDisk.fcf3dcec-fb8d-49f5-9d8c-b15edcff704c.vhd",
      :ems_ref_obj           => nil,
      :uid_ems               => "https://chefprod5120.blob.core.windows.net/system/"\
                                "Microsoft.Compute/Images/postgres-cont/"\
                                "postgres-osDisk.fcf3dcec-fb8d-49f5-9d8c-b15edcff704c.vhd",
      :vendor                => "azure",
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

    expect(@template.ext_management_system).to eq(@ems)
    expect(@template.operating_system).to eq(nil)
    expect(@template.custom_attributes.size).to eq(0)
    expect(@template.snapshots.size).to eq(0)

    expect(@template.hardware).to have_attributes(
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

    expect(@template.hardware.disks.size).to eq(0)
    expect(@template.hardware.guest_devices.size).to eq(0)
    expect(@template.hardware.nics.size).to eq(0)
    expect(@template.hardware.networks.size).to eq(0)
  end

  def assert_specific_orchestration_template
    @orch_template = OrchestrationTemplateAzure.where(:name => "spec-deployment1-dont-delete").first
    expect(@orch_template).to have_attributes(
      :md5 => "b5711eee5c9e35a7108f19ff078b7ffa"
    )
    expect(@orch_template.description).to eql('contentVersion: 1.0.0.0')
    expect(@orch_template.content).to start_with("{\n  \"$schema\": \"http://schema.management.azure.com"\
      "/schemas/2015-01-01/deploymentTemplate.json\"")
  end

  def assert_specific_orchestration_stack
    @orch_stack = ManageIQ::Providers::Azure::CloudManager::OrchestrationStack.where(
      :name => "spec-deployment1-dont-delete").first
    expect(@orch_stack).to have_attributes(
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
    expect(parameters.size).to eq(13)

    # assert one of the parameter models
    expect(parameters[1]).to have_attributes(
      :name    => "adminUsername",
      :value   => "serveradmin",
      :ems_ref => '/subscriptions/462f2af8-e67e-40c6-9fbf-02824d1dd485/resourceGroups'\
                  '/ComputeVMs/deployments/spec-deployment1-dont-delete\adminUsername'
    )
  end

  def assert_specific_orchestration_stack_resources
    resources = @orch_stack.resources.order("ems_ref")
    expect(resources.size).to eq(9)

    # assert one of the resource models
    expect(resources.first).to have_attributes(
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
    expect(outputs.size).to eq(1)
    expect(outputs[0]).to have_attributes(
      :key         => "siteUri",
      :value       => "hard-coded output for test",
      :description => "siteUri",
      :ems_ref     => '/subscriptions/462f2af8-e67e-40c6-9fbf-02824d1dd485/resourceGroups'\
                      '/ComputeVMs/deployments/spec-deployment2-dont-delete\siteUri'
    )
  end

  def assert_specific_orchestration_stack_associations
    # orchestration stack belongs to a provider
    expect(@orch_stack.ext_management_system).to eql(@ems)

    # orchestration stack belongs to an orchestration template
    expect(@orch_stack.orchestration_template).to eql(@orch_template)

    # orchestration stack can be nested
    parent_stack = ManageIQ::Providers::Azure::CloudManager::OrchestrationStack.where(
      :name => "spec-deployment2-dont-delete").first
    child_stack = ManageIQ::Providers::Azure::CloudManager::OrchestrationStack.where(
      :name => "spec-nested-deployment-dont-delete").first
    expect(child_stack.parent).to eql(parent_stack)

    # orchestration stack can have vms
    vm = ManageIQ::Providers::Azure::CloudManager::Vm.where(:name => "spec-VM1").first
    expect(vm.orchestration_stack).to eql(@orch_stack)

    # orchestration stack can have cloud networks
    cloud_network = CloudNetwork.where(:name => 'spec-VNET').first
    expect(cloud_network.orchestration_stack).to eql(@orch_stack)
  end
end
