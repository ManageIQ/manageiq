require "spec_helper"

describe EmsRefresh::Refreshers::Ec2Refresher do
  before(:each) do
    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_amazon, :hostname => "us-west-1", :zone => zone)
    @ems.update_authentication(:default => {:userid => "0123456789ABCDEFGHIJ", :password => "ABCDEFGHIJKLMNO1234567890abcdefghijklmno"})
  end

  it "will perform a full refresh on another region" do
    2.times do  # Run twice to verify that a second run with existing data does not change anything
      @ems.reload

      VCR.use_cassette("#{described_class.name.underscore}_other_region") do
        EmsRefresh.refresh(@ems)
      end
      @ems.reload

      assert_table_counts
      assert_ems
      assert_specific_flavor
      assert_specific_az
      assert_specific_floating_ip
      assert_specific_key_pair
      assert_specific_security_group
      assert_specific_template
      assert_specific_vm_powered_on
      assert_specific_vm_in_other_region
      assert_relationship_tree
    end
  end

  def assert_table_counts
    ExtManagementSystem.count.should == 1
    Flavor.count.should              == 38
    AvailabilityZone.count.should    == 3
    FloatingIp.count.should          == 1
    AuthPrivateKey.count.should      == 2
    SecurityGroup.count.should       == 2
    FirewallRule.count.should        == 4
    VmOrTemplate.count.should        == 3
    Vm.count.should                  == 2
    MiqTemplate.count.should         == 1

    CustomAttribute.count.should     == 0
    Disk.count.should                == 1
    GuestDevice.count.should         == 0
    Hardware.count.should            == 3
    Network.count.should             == 4
    OperatingSystem.count.should     == 0 # TODO: Should this be 15 (set on all vms)?
    Snapshot.count.should            == 0
    SystemService.count.should       == 0

    Relationship.count.should        == 2
    MiqQueue.count.should            == 5
  end

  def assert_ems
    @ems.should have_attributes(
      :api_version => nil, # TODO: Should be 3.0
      :uid_ems     => nil
    )

    @ems.flavors.size.should            == 38
    @ems.availability_zones.size.should == 3
    @ems.floating_ips.size.should       == 1
    @ems.key_pairs.size.should          == 2
    @ems.security_groups.size.should    == 2
    @ems.vms_and_templates.size.should  == 3
    @ems.vms.size.should                == 2
    @ems.miq_templates.size.should      == 1
  end

  def assert_specific_flavor
    @flavor = FlavorAmazon.where(:name => "t1.micro").first
    @flavor.should have_attributes(
      :name                 => "t1.micro",
      :description          => "T1 Micro",
      :enabled              => true,
      :cpus                 => 1,
      :cpu_cores            => 1,
      :memory               => 613.megabytes.to_i,
      :supports_32_bit      => true,
      :supports_64_bit      => true,
      :supports_hvm         => false,
      :supports_paravirtual => true
    )

    @flavor.ext_management_system.should == @ems
  end

  def assert_specific_az
    @az = AvailabilityZoneAmazon.where(:name => "us-west-1a").first
    @az.should have_attributes(
      :name => "us-west-1a",
    )
  end

  def assert_specific_floating_ip
    ip = FloatingIpAmazon.where(:address => "54.215.0.230").first
    ip.should have_attributes(
      :address            => "54.215.0.230",
      :ems_ref            => "54.215.0.230",
      :cloud_network_only => false
    )
  end

  def assert_specific_key_pair
    @kp = AuthKeyPairAmazon.where(:name => "EmsRefreshSpec-KeyPair-OtherRegion").first
    @kp.should have_attributes(
      :name        => "EmsRefreshSpec-KeyPair-OtherRegion",
      :fingerprint => "fc:53:30:aa:d2:23:c7:8d:e2:e8:05:95:a0:d2:90:fb:15:30:a2:51"
    )
  end

  def assert_specific_security_group
    @sg = SecurityGroupAmazon.where(:name => "EmsRefreshSpec-SecurityGroup-OtherRegion").first
    @sg.should have_attributes(
      :name        => "EmsRefreshSpec-SecurityGroup-OtherRegion",
      :description => "EmsRefreshSpec-SecurityGroup-OtherRegion",
      :ems_ref     => "sg-2b87746f"
    )

    @sg.firewall_rules.size.should == 1
    @sg.firewall_rules.first.should have_attributes(
      :host_protocol            => "TCP",
      :direction                => "inbound",
      :port                     => 0,
      :end_port                 => 65535,
      :source_security_group_id => nil,
      :source_ip_range          => "0.0.0.0/0"
    )
  end

  def assert_specific_template
    @template = TemplateAmazon.where(:name => "EmsRefreshSpec-Image-OtherRegion").first
    @template.should have_attributes(
      :template              => true,
      :ems_ref               => "ami-183e175d",
      :ems_ref_obj           => nil,
      :uid_ems               => "ami-183e175d",
      :vendor                => "Amazon",
      :power_state           => "never",
      :location              => "123456789012/EmsRefreshSpec-Image-OtherRegion",
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
      :guest_os           => "linux",
      :guest_os_full_name => nil,
      :bios               => nil,
      :annotation         => nil,
      :numvcpus           => 1, # wtf
      :memory_cpu         => nil,
      :disk_capacity      => nil,
      :bitness            => 64
    )

    @template.hardware.disks.size.should         == 0
    @template.hardware.guest_devices.size.should == 0
    @template.hardware.nics.size.should          == 0
    @template.hardware.networks.size.should      == 0
  end

  def assert_specific_vm_powered_on
    v = VmAmazon.where(:name => "EmsRefreshSpec-PoweredOn-OtherRegion", :power_state => "on").first
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "i-dc1ee486",
      :ems_ref_obj           => nil,
      :uid_ems               => "i-dc1ee486",
      :vendor                => "Amazon",
      :power_state           => "on",
      :location              => "ec2-204-236-137-154.us-west-1.compute.amazonaws.com",
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
    v.floating_ip.should            be_nil
    v.flavor.should                 == @flavor
    v.cloud_network.should          be_nil
    v.cloud_subnet.should           be_nil
    v.security_groups.should        == [@sg]
    v.key_pairs.should              == [@kp]
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

    v.hardware.networks.size.should      == 2
    network = v.hardware.networks.where(:description => "public").first
    network.should have_attributes(
      :description => "public",
      :ipaddress   => "204.236.137.154",
      :hostname    => "ec2-204-236-137-154.us-west-1.compute.amazonaws.com"
    )
    network = v.hardware.networks.where(:description => "private").first
    network.should have_attributes(
      :description => "private",
      :ipaddress   => "10.191.129.95",
      :hostname    => "ip-10-191-129-95.us-west-1.compute.internal"
    )

    v.with_relationship_type("genealogy") do
      v.parent.should == @template
    end
  end

  def assert_specific_vm_in_other_region
    v = VmAmazon.where(:name => "EmsRefreshSpec-PoweredOn-Basic").first
    v.should be_nil
  end

  def assert_relationship_tree
    @ems.descendants_arranged.should match_relationship_tree({})
  end
end
