require "spec_helper"

describe EmsRefresh::Refreshers::Ec2Refresher do
  before(:each) do
    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_amazon, :zone => zone)
    @ems.update_authentication(:default => {:userid => "0123456789ABCDEFGHIJ", :password => "ABCDEFGHIJKLMNO1234567890abcdefghijklmno"})
  end

  it "will perform a full refresh" do
    2.times do  # Run twice to verify that a second run with existing data does not change anything
      @ems.reload

      VCR.use_cassette(described_class.name.underscore) do
        EmsRefresh.refresh(@ems)
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
      assert_relationship_tree
    end
  end

  def assert_table_counts
    ExtManagementSystem.count.should == 1
    Flavor.count.should              == 38
    AvailabilityZone.count.should    == 5
    FloatingIp.count.should          == 4
    AuthPrivateKey.count.should      == 6
    CloudNetwork.count.should        == 1
    CloudSubnet.count.should         == 2
    SecurityGroup.count.should       == 9
    FirewallRule.count.should        == 35
    VmOrTemplate.count.should        == 42
    Vm.count.should                  == 23
    MiqTemplate.count.should         == 19

    CustomAttribute.count.should     == 0
    Disk.count.should                == 15
    GuestDevice.count.should         == 0
    Hardware.count.should            == 42
    Network.count.should             == 27
    OperatingSystem.count.should     == 0 # TODO: Should this be 13 (set on all vms)?
    Snapshot.count.should            == 0
    SystemService.count.should       == 0

    Relationship.count.should        == 22
    MiqQueue.count.should            == 44
  end

  def assert_ems
    @ems.should have_attributes(
      :api_version => nil, # TODO: Should be 3.0
      :uid_ems     => nil
    )

    @ems.flavors.size.should            == 38
    @ems.availability_zones.size.should == 5
    @ems.floating_ips.size.should       == 4
    @ems.key_pairs.size.should          == 6
    @ems.cloud_networks.size.should     == 1
    @ems.security_groups.size.should    == 9
    @ems.vms_and_templates.size.should  == 42
    @ems.vms.size.should                == 23
    @ems.miq_templates.size.should      == 19
  end

  def assert_specific_flavor
    @flavor = Flavor.where(:name => "t1.micro").first
    @flavor.should be_kind_of(FlavorAmazon)
    @flavor.should have_attributes(
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
    )

    @flavor.ext_management_system.should == @ems
  end

  def assert_specific_az
    @az = AvailabilityZone.where(:name => "us-east-1b").first
    @az.should be_kind_of(AvailabilityZoneAmazon)
    @az.should have_attributes(
      :name => "us-east-1b",
    )
  end

  def assert_specific_floating_ip
    @ip = FloatingIp.where(:address => "54.221.202.53").first
    @ip.should be_kind_of(FloatingIpAmazon)
    @ip.should have_attributes(
      :address            => "54.221.202.53",
      :ems_ref            => "54.221.202.53",
      :cloud_network_only => false
    )
  end

  def assert_specific_floating_ip_for_cloud_network
    ip = FloatingIp.where(:address => "54.208.119.197").first
    ip.should be_kind_of(FloatingIpAmazon)
    ip.should have_attributes(
      :address            => "54.208.119.197",
      :ems_ref            => "54.208.119.197",
      :cloud_network_only => true
    )
  end

  def assert_specific_key_pair
    @kp = AuthPrivateKey.where(:name => "EmsRefreshSpec-KeyPair").first
    @kp.should have_attributes(
      :name        => "EmsRefreshSpec-KeyPair",
      :fingerprint => "49:9f:3f:a4:26:48:39:94:26:06:dd:25:73:e5:da:9b:4b:1b:6c:93"
    )
  end

  def assert_specific_cloud_network
    @cn = CloudNetwork.where(:name => "EmsRefreshSpec-VPC").first
    @cn.should have_attributes(
      :name    => "EmsRefreshSpec-VPC",
      :ems_ref => "vpc-ff49ff91",
      :cidr    => "10.0.0.0/16",
      :status  => "active",
      :enabled => true
    )

    @cn.cloud_subnets.size.should == 2
    @subnet = @cn.cloud_subnets.where(:name => "EmsRefreshSpec-Subnet1").first
    @subnet.should have_attributes(
      :name    => "EmsRefreshSpec-Subnet1",
      :ems_ref => "subnet-f849ff96",
      :cidr    => "10.0.0.0/24"
    )
    @subnet.availability_zone.should == AvailabilityZoneAmazon.where(:name => "us-east-1e").first

    subnet2 = @cn.cloud_subnets.where(:name => "EmsRefreshSpec-Subnet2").first
    subnet2.should have_attributes(
      :name    => "EmsRefreshSpec-Subnet2",
      :ems_ref => "subnet-16c70477",
      :cidr    => "10.0.1.0/24"
    )
    subnet2.availability_zone.should == AvailabilityZoneAmazon.where(:name => "us-east-1d").first
  end

  def assert_specific_security_group
    @sg = SecurityGroup.where(:name => "EmsRefreshSpec-SecurityGroup").first
    @sg.should have_attributes(
      :name        => "EmsRefreshSpec-SecurityGroup",
      :description => "EmsRefreshSpec-SecurityGroup",
      :ems_ref     => "sg-88af19e3"
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

    @sg.firewall_rules.size.should == 12
    @sg.firewall_rules.
      order(:host_protocol, :direction, :port, :end_port, :source_ip_range, :source_security_group_id).
      zip(expected_firewall_rules).
      each do |actual, expected|
        actual.should have_attributes(expected)
      end
  end

  def assert_specific_security_group_on_cloud_network
    @sg_on_cn = SecurityGroup.where(:name => "EmsRefreshSpec-SecurityGroup-VPC").first
    @sg_on_cn.should have_attributes(
      :name        => "EmsRefreshSpec-SecurityGroup-VPC",
      :description => "EmsRefreshSpec-SecurityGroup-VPC",
      :ems_ref     => "sg-80f755ef"
    )

    @sg_on_cn.cloud_network.should == @cn
  end

  def assert_specific_template
    @template = MiqTemplate.where(:name => "EmsRefreshSpec-Image").first
    @template.should have_attributes(
      :template              => true,
      :ems_ref               => "ami-5769193e",
      :ems_ref_obj           => nil,
      :uid_ems               => "ami-5769193e",
      :vendor                => "Amazon",
      :power_state           => "never",
      :location              => "123456789012/EmsRefreshSpec-Image",
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

    @template.ext_management_system.should  == @ems
    @template.operating_system.should       be_nil # TODO: This should probably not be nil
    @template.custom_attributes.size.should == 0
    @template.snapshots.size.should         == 0

    @template.hardware.should have_attributes(
      :guest_os            => "linux",
      :guest_os_full_name  => nil,
      :bios                => nil,
      :annotation          => nil,
      :numvcpus            => 1, # wtf
      :memory_cpu          => nil,
      :disk_capacity       => nil,
      :bitness             => 64,
      :virtualization_type => "paravirtual",
      :root_device_type    => "ebs"
    )

    @template.hardware.disks.size.should         == 0
    @template.hardware.guest_devices.size.should == 0
    @template.hardware.nics.size.should          == 0
    @template.hardware.networks.size.should      == 0
  end

  def assert_specific_shared_template
    t = MiqTemplate.where(:ems_ref => "ami-5e094837").first # TODO: Share an EmsRefreshSpec specific template
    t.should_not be_nil
  end

  def assert_specific_vm_powered_on
    v = Vm.where(:name => "EmsRefreshSpec-PoweredOn-Basic", :power_state => "on").first
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "i-7ab3c301",
      :ems_ref_obj           => nil,
      :uid_ems               => "i-7ab3c301",
      :vendor                => "Amazon",
      :power_state           => "on",
      :location              => "ec2-54-221-202-53.compute-1.amazonaws.com",
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

    v.ext_management_system.should  == @ems
    v.availability_zone.should      == @az
    v.floating_ip.should            == @ip
    v.flavor.should                 == @flavor
    v.key_pairs.should              == [@kp]
    v.cloud_network.should          be_nil
    v.cloud_subnet.should           be_nil
    v.security_groups.should        match_array [@sg, SecurityGroup.where(:name => "EmsRefreshSpec-SecurityGroup2").first]

    v.operating_system.should       be_nil # TODO: This should probably not be nil
    v.custom_attributes.size.should == 0
    v.snapshots.size.should         == 0

    v.hardware.should have_attributes(
      :guest_os            => "linux",
      :guest_os_full_name  => nil,
      :bios                => nil,
      :annotation          => nil,
      :numvcpus            => 1,
      :memory_cpu          => 613, # MB
      :disk_capacity       => 0, # TODO: Change to a flavor that has disks
      :bitness             => 64,
      :virtualization_type => "paravirtual"
    )

    v.hardware.disks.size.should         == 0 # TODO: Change to a flavor that has disks
    v.hardware.guest_devices.size.should == 0
    v.hardware.nics.size.should          == 0

    v.hardware.networks.size.should      == 2
    network = v.hardware.networks.where(:description => "public").first
    network.should have_attributes(
      :description => "public",
      :ipaddress   => @ip.address,
      :hostname    => "ec2-54-221-202-53.compute-1.amazonaws.com"
    )
    network = v.hardware.networks.where(:description => "private").first
    network.should have_attributes(
      :description => "private",
      :ipaddress   => "10.46.222.159",
      :hostname    => "ip-10-46-222-159.ec2.internal"
    )

    v.with_relationship_type("genealogy") do
      v.parent.should == @template
    end
  end

  def assert_specific_vm_powered_off
    v = Vm.where(:name => "EmsRefreshSpec-PoweredOff", :power_state => "off").first
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "i-79188d11",
      :ems_ref_obj           => nil,
      :uid_ems               => "i-79188d11",
      :vendor                => "Amazon",
      :power_state           => "off",
      :location              => "unknown",
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

    v.ext_management_system.should  == @ems
    v.availability_zone.should      == AvailabilityZone.find_by_name("us-east-1d")
    v.floating_ip.should            be_nil
    v.key_pairs.should              == [@kp]
    v.cloud_network.should          be_nil
    v.cloud_subnet.should           be_nil
    v.security_groups.should        == [@sg]
    v.operating_system.should       be_nil # TODO: This should probably not be nil
    v.custom_attributes.size.should == 0
    v.snapshots.size.should         == 0

    v.hardware.should have_attributes(
      :guest_os           => "linux",
      :guest_os_full_name => nil,
      :bios               => nil,
      :annotation         => nil,
      :numvcpus           => 1,
      :memory_cpu         => 613, # MB
      :disk_capacity      => 0, # TODO: Change to a flavor that has disks
      :bitness            => 64
    )

    v.hardware.disks.size.should         == 0 # TODO: Change to a flavor that has disks
    v.hardware.guest_devices.size.should == 0
    v.hardware.nics.size.should          == 0
    v.hardware.networks.size.should      == 0

    v.with_relationship_type("genealogy") do
      v.parent.should == @template
    end
  end

  def assert_specific_vm_on_cloud_network
    v = Vm.where(:name => "EmsRefreshSpec-PoweredOn-VPC").first
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "i-8b5739f2",
      :ems_ref_obj           => nil,
      :uid_ems               => "i-8b5739f2",
      :vendor                => "Amazon",
      :power_state           => "on",
      :location              => "unknown",
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

    v.cloud_network.should     == @cn
    v.cloud_subnet.should      == @subnet
    v.security_groups.should   == [@sg_on_cn]
  end

  def assert_specific_vm_in_other_region
    v = Vm.where(:name => "EmsRefreshSpec-PoweredOn-OtherRegion").first
    v.should be_nil
  end

  def assert_relationship_tree
    @ems.descendants_arranged.should match_relationship_tree({})
  end
end
