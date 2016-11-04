describe ManageIQ::Providers::Amazon::CloudManager::Refresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_amazon, :zone => zone)
    @ems.update_authentication(:default => {:userid => "0123456789ABCDEFGHIJ", :password => "ABCDEFGHIJKLMNO1234567890abcdefghijklmno"})
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:ec2)
  end

  it "will perform a full refresh" do
    2.times do # Run twice to verify that a second run with existing data does not change anything
      @ems.reload

      VCR.use_cassette(described_class.name.underscore) do
        EmsRefresh.refresh(@ems)
        EmsRefresh.refresh(@ems.network_manager)
      end
      @ems.reload

      assert_table_counts
      assert_ems
      assert_specific_flavor
      assert_specific_az
      assert_specific_floating_ip
      assert_specific_floating_ip_for_cloud_network
      assert_specific_key_pair
      assert_specific_cloud_network
      assert_specific_security_group
      assert_specific_security_group_on_cloud_network
      assert_specific_template
      assert_specific_shared_template
      assert_specific_vm_powered_on
      assert_specific_vm_powered_off
      assert_specific_vm_on_cloud_network
      assert_specific_vm_in_other_region
      assert_specific_orchestration_template
      assert_specific_orchestration_stack
      assert_relationship_tree
    end
  end

  def assert_table_counts
    expect(ExtManagementSystem.count).to eq(2)
    expect(Flavor.count).to eq(56)
    expect(AvailabilityZone.count).to eq(5)
    expect(FloatingIp.count).to eq(9)
    expect(AuthPrivateKey.count).to eq(12)
    expect(CloudNetwork.count).to eq(5)
    expect(CloudSubnet.count).to eq(10)
    expect(OrchestrationTemplate.count).to eq(2)
    expect(OrchestrationStack.count).to eq(2)
    expect(OrchestrationStackParameter.count).to eq(5)
    expect(OrchestrationStackOutput.count).to eq(1)
    expect(OrchestrationStackResource.count).to eq(24)
    expect(SecurityGroup.count).to eq(36)
    expect(FirewallRule.count).to eq(94)
    expect(VmOrTemplate.count).to eq(47)
    expect(Vm.count).to eq(27)
    expect(MiqTemplate.count).to eq(20)

    expect(CustomAttribute.count).to eq(0)
    expect(Disk.count).to eq(14)
    expect(GuestDevice.count).to eq(0)
    expect(Hardware.count).to eq(47)
    expect(Network.count).to eq(15)
    expect(OperatingSystem.count).to eq(0) # TODO: Should this be 13 (set on all vms)?
    expect(Snapshot.count).to eq(0)
    expect(SystemService.count).to eq(0)

    expect(Relationship.count).to eq(26)
    expect(MiqQueue.count).to eq(50)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :api_version => nil, # TODO: Should be 3.0
      :uid_ems     => nil
    )

    expect(@ems.flavors.size).to eq(56)
    expect(@ems.availability_zones.size).to eq(5)
    expect(@ems.floating_ips.size).to eq(9)
    expect(@ems.key_pairs.size).to eq(12)
    expect(@ems.cloud_networks.size).to eq(5)
    expect(@ems.security_groups.size).to eq(36)
    expect(@ems.vms_and_templates.size).to eq(47)
    expect(@ems.vms.size).to eq(27)
    expect(@ems.miq_templates.size).to eq(20)
    expect(@ems.orchestration_stacks.size).to eq(2)

    expect(@ems.direct_orchestration_stacks.size).to eq(1)
  end

  def assert_specific_flavor
    @flavor = ManageIQ::Providers::Amazon::CloudManager::Flavor.where(:name => "t1.micro").first
    expect(@flavor).to have_attributes(
      :name                     => "t1.micro",
      :description              => "T1 Micro",
      :enabled                  => true,
      :cpus                     => 1,
      :cpu_cores                => 1,
      :memory                   => 613.megabytes.to_i,
      :supports_32_bit          => true,
      :supports_64_bit          => true,
      :supports_hvm             => false,
      :supports_paravirtual     => true,
      :block_storage_based_only => true,
      :ephemeral_disk_size      => 0,
      :ephemeral_disk_count     => 0
    )

    expect(@flavor.ext_management_system).to eq(@ems)
  end

  def assert_specific_az
    @az = ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone.where(:name => "us-east-1e").first
    expect(@az).to have_attributes(
      :name => "us-east-1e",
    )
  end

  def assert_specific_floating_ip
    @ip = ManageIQ::Providers::Amazon::NetworkManager::FloatingIp.where(:address => "54.221.202.53").first
    expect(@ip).to have_attributes(
      :address            => "54.221.202.53",
      :ems_ref            => "54.221.202.53",
      :cloud_network_only => false
    )
  end

  def assert_specific_floating_ip_for_cloud_network
    @ip2 = ManageIQ::Providers::Amazon::NetworkManager::FloatingIp.where(:address => "54.208.119.197").first
    expect(@ip2).to have_attributes(
      :address            => "54.208.119.197",
      :ems_ref            => "eipalloc-ce53d7a0",
      :cloud_network_only => true,
      :network_port_id    => nil,
      :vm_id              => nil
    )

    @ip1 = ManageIQ::Providers::Amazon::NetworkManager::FloatingIp.where(:address => "52.20.255.156").first
    expect(@ip1).to have_attributes(
      :address            => "52.20.255.156",
      :ems_ref            => "eipalloc-00db5764",
      :cloud_network_only => true
    )
  end

  def assert_specific_key_pair
    @kp = ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair.where(:name => "EmsRefreshSpec-KeyPair").first
    expect(@kp).to have_attributes(
      :name        => "EmsRefreshSpec-KeyPair",
      :fingerprint => "49:9f:3f:a4:26:48:39:94:26:06:dd:25:73:e5:da:9b:4b:1b:6c:93"
    )
  end

  def assert_specific_cloud_network
    @cn = CloudNetwork.where(:name => "EmsRefreshSpec-VPC").first
    expect(@cn).to have_attributes(
      :name    => "EmsRefreshSpec-VPC",
      :ems_ref => "vpc-ff49ff91",
      :cidr    => "10.0.0.0/16",
      :status  => "inactive",
      :enabled => true
    )

    expect(@cn.cloud_subnets.size).to eq(2)
    @subnet = @cn.cloud_subnets.where(:name => "EmsRefreshSpec-Subnet1").first
    expect(@subnet).to have_attributes(
      :name    => "EmsRefreshSpec-Subnet1",
      :ems_ref => "subnet-f849ff96",
      :cidr    => "10.0.0.0/24"
    )
    expect(@subnet.availability_zone)
      .to eq(ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone.where(:name => "us-east-1e").first)

    subnet2 = @cn.cloud_subnets.where(:name => "EmsRefreshSpec-Subnet2").first
    expect(subnet2).to have_attributes(
      :name    => "EmsRefreshSpec-Subnet2",
      :ems_ref => "subnet-16c70477",
      :cidr    => "10.0.1.0/24"
    )
    expect(subnet2.availability_zone)
      .to eq(ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone.where(:name => "us-east-1d").first)
  end

  def assert_specific_security_group
    @sg = ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup.where(:name => "EmsRefreshSpec-SecurityGroup1").first
    expect(@sg).to have_attributes(
      :name        => "EmsRefreshSpec-SecurityGroup1",
      :description => "EmsRefreshSpec-SecurityGroup1",
      :ems_ref     => "sg-038e8a69"
    )

    expected_firewall_rules = [
      {:host_protocol => "ICMP", :direction => "inbound", :port => -1, :end_port => -1,    :source_ip_range => "0.0.0.0/0",  :source_security_group_id => nil},
      {:host_protocol => "ICMP", :direction => "inbound", :port => -1, :end_port => -1,    :source_ip_range => nil,          :source_security_group_id => @sg.id},
      {:host_protocol => "ICMP", :direction => "inbound", :port => 0,  :end_port => -1,    :source_ip_range => "1.2.3.4/30", :source_security_group_id => nil},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 0,  :end_port => 65535, :source_ip_range => "0.0.0.0/0",  :source_security_group_id => nil},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 1,  :end_port => 2,     :source_ip_range => "1.2.3.4/30", :source_security_group_id => nil},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 3,  :end_port => 4,     :source_ip_range => nil,          :source_security_group_id => @sg.id},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 80, :end_port => 80,    :source_ip_range => "0.0.0.0/0",  :source_security_group_id => nil},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 80, :end_port => 80,    :source_ip_range => "1.2.3.4/30", :source_security_group_id => nil},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 80, :end_port => 80,    :source_ip_range => nil,          :source_security_group_id => @sg.id},
      {:host_protocol => "UDP",  :direction => "inbound", :port => 0,  :end_port => 65535, :source_ip_range => "0.0.0.0/0",  :source_security_group_id => nil},
      {:host_protocol => "UDP",  :direction => "inbound", :port => 1,  :end_port => 2,     :source_ip_range => "1.2.3.4/30", :source_security_group_id => nil},
      {:host_protocol => "UDP",  :direction => "inbound", :port => 3,  :end_port => 4,     :source_ip_range => nil,          :source_security_group_id => @sg.id}
    ]

    expect(@sg.firewall_rules.size).to eq(12)
    @sg.firewall_rules
      .order(:host_protocol, :direction, :port, :end_port, :source_ip_range, :source_security_group_id)
      .zip(expected_firewall_rules)
      .each do |actual, expected|
        expect(actual).to have_attributes(expected)
      end
  end

  def assert_specific_security_group_on_cloud_network
    @sg_on_cn = ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup.where(:name => "EmsRefreshSpec-SecurityGroup-VPC").first
    expect(@sg_on_cn).to have_attributes(
      :name        => "EmsRefreshSpec-SecurityGroup-VPC",
      :description => "EmsRefreshSpec-SecurityGroup-VPC",
      :ems_ref     => "sg-80f755ef"
    )

    expect(@sg_on_cn.cloud_network).to eq(@cn)
  end

  def assert_specific_template
    @template = ManageIQ::Providers::Amazon::CloudManager::Template.where(:name => "EmsRefreshSpec-Image").first
    expect(@template).to have_attributes(
      :template              => true,
      :ems_ref               => "ami-5769193e",
      :ems_ref_obj           => nil,
      :uid_ems               => "ami-5769193e",
      :vendor                => "amazon",
      :power_state           => "never",
      :location              => "200278856672/EmsRefreshSpec-Image",
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
    expect(@template.operating_system).to       be_nil # TODO: This should probably not be nil
    expect(@template.custom_attributes.size).to eq(0)
    expect(@template.snapshots.size).to eq(0)

    expect(@template.hardware).to have_attributes(
      :guest_os            => "linux",
      :guest_os_full_name  => nil,
      :bios                => nil,
      :annotation          => nil,
      :cpu_sockets         => 1, # wtf
      :memory_mb           => nil,
      :disk_capacity       => nil,
      :bitness             => 64,
      :virtualization_type => "paravirtual",
      :root_device_type    => "ebs"
    )

    expect(@template.hardware.disks.size).to eq(0)
    expect(@template.hardware.guest_devices.size).to eq(0)
    expect(@template.hardware.nics.size).to eq(0)
    expect(@template.hardware.networks.size).to eq(0)
  end

  def assert_specific_shared_template
    # TODO: Share an EmsRefreshSpec specific template
    t = ManageIQ::Providers::Amazon::CloudManager::Template.where(:ems_ref => "ami-5769193e").first
    expect(t).not_to be_nil
  end

  def assert_specific_vm_powered_on
    v = ManageIQ::Providers::Amazon::CloudManager::Vm.where(
      :name            => "EmsRefreshSpec-PoweredOn-Basic3",
      :raw_power_state => "running").first
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "i-680071e9",
      :ems_ref_obj           => nil,
      :uid_ems               => "i-680071e9",
      :vendor                => "amazon",
      :power_state           => "on",
      :location              => "ec2-54-221-202-53.compute-1.amazonaws.com",
      :tools_status          => nil,
      :boot_time             => "2016-03-29T07:49:56.000",
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

    expect(v.ext_management_system).to eq(@ems)
    expect(v.availability_zone).to eq(@az)
    expect(v.floating_ip).to eq(@ip)
    expect(v.network_ports.first.floating_ips.count).to eq(1)
    expect(v.network_ports.first.floating_ips).to eq([@ip])
    expect(v.network_ports.first.floating_ip_addresses).to eq([@ip.address])
    expect(v.network_ports.first.fixed_ip_addresses).to eq([@ip.fixed_ip_address])
    expect(v.network_ports.first.ipaddresses).to eq([@ip.fixed_ip_address, @ip.address])
    expect(v.ipaddresses).to eq([@ip.fixed_ip_address, @ip.address])
    expect(v.flavor).to eq(@flavor)
    expect(v.key_pairs).to eq([@kp])
    expect(v.cloud_network).to     be_nil
    expect(v.cloud_subnet).to      be_nil
    sg_2 = ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup
           .where(:name => "EmsRefreshSpec-SecurityGroup2").first
    expect(v.security_groups)
      .to match_array [sg_2, @sg]

    expect(v.operating_system).to       be_nil # TODO: This should probably not be nil
    expect(v.custom_attributes.size).to eq(0)
    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to have_attributes(
      :guest_os            => "linux",
      :guest_os_full_name  => nil,
      :bios                => nil,
      :annotation          => nil,
      :cpu_sockets         => 1,
      :memory_mb           => 613,
      :disk_capacity       => 0, # TODO: Change to a flavor that has disks
      :bitness             => 64,
      :virtualization_type => "paravirtual"
    )

    expect(v.hardware.disks.size).to eq(0) # TODO: Change to a flavor that has disks
    expect(v.hardware.guest_devices.size).to eq(0)
    expect(v.hardware.nics.size).to eq(0)

    expect(v.hardware.networks.size).to eq(2)
    network = v.hardware.networks.where(:description => "public").first
    expect(network).to have_attributes(
      :description => "public",
      :ipaddress   => @ip.address,
      :hostname    => "ec2-54-221-202-53.compute-1.amazonaws.com"
    )
    network = v.hardware.networks.where(:description => "private").first
    expect(network).to have_attributes(
      :description => "private",
      :ipaddress   => "10.65.160.22",
      :hostname    => "ip-10-65-160-22.ec2.internal"
    )

    v.with_relationship_type("genealogy") do
      expect(v.parent).to eq(@template)
    end
  end

  def assert_specific_vm_powered_off
    v = ManageIQ::Providers::Amazon::CloudManager::Vm.where(
      :name            => "EmsRefreshSpec-PoweredOff",
      :raw_power_state => "stopped").first
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "i-6eeb97ef",
      :ems_ref_obj           => nil,
      :uid_ems               => "i-6eeb97ef",
      :vendor                => "amazon",
      :power_state           => "off",
      :location              => "unknown",
      :tools_status          => nil,
      :boot_time             => "2016-01-08T15:09:18.000",
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

    expect(v.ext_management_system).to eq(@ems)
    expect(v.availability_zone)
      .to eq(ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone.find_by_name("us-east-1e"))
    expect(v.floating_ip).to be_nil
    expect(v.key_pairs).to eq([@kp])
    expect(v.cloud_network).to be_nil
    expect(v.cloud_subnet).to be_nil
    expect(v.security_groups).to eq([@sg])
    expect(v.operating_system).to be_nil # TODO: This should probably not be nil
    expect(v.custom_attributes.size).to eq(0)
    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to have_attributes(
      :config_version       => nil,
      :virtual_hw_version   => nil,
      :guest_os             => "linux",
      :cpu_sockets          => 1,
      :bios                 => nil,
      :bios_location        => nil,
      :time_sync            => nil,
      :annotation           => nil,
      :memory_mb            => 613,
      :host_id              => nil,
      :cpu_speed            => nil,
      :cpu_type             => nil,
      :size_on_disk         => nil,
      :manufacturer         => "",
      :model                => "",
      :number_of_nics       => nil,
      :cpu_usage            => nil,
      :memory_usage         => nil,
      :cpu_cores_per_socket => 1,
      :cpu_total_cores      => 1,
      :vmotion_enabled      => nil,
      :disk_free_space      => nil,
      :disk_capacity        => 0,
      :guest_os_full_name   => nil,
      :memory_console       => nil,
      :bitness              => 64,
      :virtualization_type  => "paravirtual",
      :root_device_type     => "ebs",
    )

    expect(v.hardware.disks.size).to eq(0) # TODO: Change to a flavor that has disks
    expect(v.hardware.guest_devices.size).to eq(0)
    expect(v.hardware.nics.size).to eq(0)
    expect(v.hardware.networks.size).to eq(0)

    v.with_relationship_type("genealogy") do
      expect(v.parent).to eq(@template)
    end
  end

  def assert_specific_vm_on_cloud_network
    v = ManageIQ::Providers::Amazon::CloudManager::Vm.where(:name => "EmsRefreshSpec-PoweredOn-VPC").first
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "i-8b5739f2",
      :ems_ref_obj           => nil,
      :uid_ems               => "i-8b5739f2",
      :vendor                => "amazon",
      :power_state           => "on",
      :location              => "unknown",
      :tools_status          => nil,
      :boot_time             => "2013-09-23T20:11:52.000",
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

    expect(v.cloud_networks.first).to eq(@cn)
    expect(v.cloud_subnets.first).to eq(@subnet)
    expect(v.security_groups).to eq([@sg_on_cn])
    expect(v.floating_ip).to eq(@ip1)
    expect(v.floating_ips).to eq([@ip1])
    expect(v.network_ports.first.floating_ips.count).to eq(1)
    expect(v.network_ports.first.floating_ips).to eq([@ip1])
    expect(v.network_ports.first.floating_ip_addresses).to eq([@ip1.address])
    expect(v.network_ports.first.fixed_ip_addresses).to eq([@ip1.fixed_ip_address])
    expect(v.network_ports.first.ipaddresses).to eq([@ip1.fixed_ip_address, @ip1.address])
    expect(v.ipaddresses).to eq([@ip1.fixed_ip_address, @ip1.address])
  end

  def assert_specific_orchestration_template
    @orch_template = OrchestrationTemplateCfn.where(:md5 => "e929859521d64ac28ee29f8526d33e8f").first
    expect(@orch_template.description).to start_with("AWS CloudFormation Sample Template WordPress_Simple:")
    expect(@orch_template.content).to start_with("{\n  \"AWSTemplateFormatVersion\" : \"2010-09-09\",")
    expect(@orch_template).to have_attributes(:draft => false, :orderable => false)
  end

  def assert_specific_orchestration_stack
    stack = ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack.where(
      :name => "EmsRefreshSpec-JoeV-050").first
    expect(stack.status_reason)
      .to eq("The following resource(s) failed to create: [WebServerWaitCondition, IPAddress]. ")

    @orch_stack = ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack.where(
      :name => "EmsRefreshSpec-JoeV-050-WebServerInstance-1KRT71SKWBZ1I").first
    expect(@orch_stack).to have_attributes(
      :status  => "CREATE_COMPLETE",
      :ems_ref => "arn:aws:cloudformation:us-east-1:200278856672:stack/EmsRefreshSpec-JoeV-050-WebServerInstance-1KRT71SKWBZ1I/bff036f0-ba27-11e5-b4be-500c5242948e",
    )
    expect(@orch_stack.description).to start_with("AWS CloudFormation Sample Template WordPress_Simple:")

    assert_specific_orchestration_stack_parameters
    assert_specific_orchestration_stack_resources
    assert_specific_orchestration_stack_outputs
    assert_specific_orchestration_stack_associations
  end

  def assert_specific_orchestration_stack_parameters
    parameters = @orch_stack.parameters.order("ems_ref")
    expect(parameters.size).to eq(2)

    # assert one of the parameter models
    expect(parameters[1]).to have_attributes(
      :name  => "InstanceType",
      :value => "t1.micro"
    )
  end

  def assert_specific_orchestration_stack_resources
    resources = @orch_stack.resources.order("ems_ref")
    expect(resources.size).to eq(4)

    # assert one of the resource models
    expect(resources[3]).to have_attributes(
      :name                   => "WebServer",
      :logical_resource       => "WebServer",
      :physical_resource      => "i-7c3c64fd",
      :resource_category      => "AWS::EC2::Instance",
      :resource_status        => "CREATE_COMPLETE",
      :resource_status_reason => nil,
    )
  end

  def assert_specific_orchestration_stack_outputs
    outputs = @orch_stack.outputs
    expect(outputs.size).to eq(1)
    expect(outputs[0]).to have_attributes(
      :key         => "WebsiteURL",
      :value       => "http://ec2-54-205-48-36.compute-1.amazonaws.com/wordpress",
      :description => "WordPress Website"
    )
  end

  def assert_specific_orchestration_stack_associations
    # orchestration stack belongs to a provider
    expect(@orch_stack.ext_management_system).to eq(@ems)

    # orchestration stack belongs to an orchestration template
    expect(@orch_stack.orchestration_template).to eq(@orch_template)

    # orchestration stack can be nested
    parent_stack = OrchestrationStack.where(:name => "EmsRefreshSpec-JoeV-050").first
    expect(@orch_stack.parent).to eq(parent_stack)

    # orchestration stack can have vms
    vm = Vm.where(:name => "i-7c3c64fd").first
    expect(vm.orchestration_stack).to eq(@orch_stack)

    # orchestration stack can have security groups
    sg = SecurityGroup.where(
      :name => "EmsRefreshSpec-JoeV-050-WebServerInstance-1KRT71SKWBZ1I-WebServerSecurityGroup-13RL8S2C6ZWI1").first
    expect(sg.orchestration_stack).to eq(@orch_stack)

    # orchestration stack can have cloud networks
    vpc = CloudNetwork.where(:name => "vpc-d7b4c7b3").first
    expect(vpc.orchestration_stack).to eq(parent_stack)
  end

  def assert_specific_vm_in_other_region
    v = ManageIQ::Providers::Amazon::CloudManager::Vm.where(:name => "EmsRefreshSpec-PoweredOn-OtherRegion").first
    expect(v).to be_nil
  end

  def assert_relationship_tree
    expect(@ems.descendants_arranged).to match_relationship_tree({})
  end
end
