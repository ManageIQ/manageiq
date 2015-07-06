require "spec_helper"

describe EmsRefresh::Refreshers::OpenstackRefresher do
  before(:each) do
    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_openstack, :zone => zone, :hostname => "1.2.3.4", :ipaddress => "1.2.3.4", :port => 5000)
    @ems.update_authentication(:default => {:userid => "admin", :password => "password"})
  end

  def with_cassette
    # Caching OpenStack info between runs causes the tests to fail with:
    #   VCR::Errors::UnusedHTTPInteractionError
    # Reset the cache so HTTP interactions are the same between runs.
    @ems.reset_openstack_handle

    # We need VCR to match requests differently here because fog adds a dynamic
    #   query param to avoid HTTP caching - ignore_awful_caching##########
    #   https://github.com/fog/fog/blob/master/lib/fog/openstack/compute.rb#L308
    VCR.use_cassette("#{described_class.name.underscore}_rhos_havana", :match_requests_on => [:method, :host, :path]) do
      yield
    end
  end

  it "will perform a full refresh against RHOS Havana" do
    2.times do  # Run twice to verify that a second run with existing data does not change anything
      with_cassette do
        EmsRefresh.refresh(@ems)
      end
      @ems.reload

      assert_table_counts
      assert_ems
      # assert_specific_host
      assert_specific_flavor
      assert_specific_az
      assert_availability_zone_null
      assert_specific_tenant
      assert_specific_floating_ip
      assert_specific_key_pair
      assert_specific_security_group
      assert_specific_network
      assert_specific_private_template
      assert_specific_public_template
      assert_specific_vm_powered_on
      assert_specific_template_created_from_vm
      assert_specific_vm_created_from_snapshot_template
      assert_specific_vm_paused
      assert_specific_vm_suspended
      assert_relationship_tree
    end
  end

  context "when configured with skips" do
    before(:each) do
      VMDB::Config.any_instance.stub(:config).and_return(
        :ems_refresh => {:openstack => {:inventory_ignore => [:cloud_volumes, :cloud_volume_snapshots]}}
      )
    end

    it "will not parse the ignored items" do
      with_cassette do
        EmsRefresh.refresh(@ems)
      end

      CloudVolume.count.should   == 0

      # .. but other things are still present:
      FloatingIp.count.should    == 4
      Disk.count.should          == 21
    end
  end

  def assert_table_counts
    ExtManagementSystem.count.should == 1
    Flavor.count.should              == 6
    AvailabilityZone.count.should    == 2
    FloatingIp.count.should          == 4
    AuthPrivateKey.count.should      == 2
    SecurityGroup.count.should       == 8
    FirewallRule.count.should        == 40
    CloudNetwork.count.should        == 5
    CloudSubnet.count.should         == 5
    CloudVolume.count.should         == 5
    VmOrTemplate.count.should        == 21
    Vm.count.should                  == 13
    MiqTemplate.count.should         == 8

    CustomAttribute.count.should     == 0
    Disk.count.should                == 21
    GuestDevice.count.should         == 0
    Hardware.count.should            == 13
    Network.count.should             == 11
    OperatingSystem.count.should     == 0
    Snapshot.count.should            == 0
    SystemService.count.should       == 0

    Relationship.count.should        == 17
    MiqQueue.count.should            == 24
  end

  def assert_ems
    @ems.should have_attributes(
      :api_version => nil, # TODO: Should be 2.0?
      :uid_ems     => nil
    )

    @ems.flavors.size.should            == 6
    @ems.availability_zones.size.should == 2
    @ems.floating_ips.size.should       == 4
    @ems.key_pairs.size.should          == 2
    @ems.security_groups.size.should    == 8
    @ems.vms_and_templates.size.should  == 21
    @ems.vms.size.should                == 13
    @ems.miq_templates.size.should      == 8
  end

  # def assert_specific_host
  #   @host = Host.find_by_name("openstackalamo-folsom")
  #   @host.should have_attributes(
  #     :ems_ref          => "openstackalamo-folsom",
  #     :ems_ref_obj      => nil,
  #     :name             => "openstackalamo-folsom",
  #     :hostname         => nil,
  #     :ipaddress        => nil,
  #     :uid_ems          => "openstackalamo-folsom",
  #     :vmm_vendor       => "OpenStack",
  #     :vmm_version      => nil,
  #     :vmm_product      => nil,
  #     :vmm_buildnumber  => nil,
  #     :power_state      => "unknown",
  #     :connection_state => nil
  #   )

  #   @host.ems_cluster.should          be_nil
  #   @host.storages.size.should        == 0
  #   @host.operating_system.should     be_nil
  #   @host.system_services.size.should == 0
  #   @host.switches.size.should        == 0

  #   @host.hardware.should have_attributes(
  #     :numvcpus   => 4,
  #     :memory_cpu => 7983
  #   )

  #   @host.hardware.disks.size.should == 1
  #   disk = @host.hardware.disks.first
  #   disk.should have_attributes(
  #     :device_name => nil,
  #     :device_type => "disk",
  #     :size        => 41.gigabytes,
  #   )
  # end

  def assert_specific_flavor
    @flavor = FlavorOpenstack.where(:name => "m1.ems_refresh_spec").first
    @flavor.should have_attributes(
      :name        => "m1.ems_refresh_spec",
      :description => nil,
      :enabled     => true,
      :cpus        => 1,
      :cpu_cores   => nil,
      :memory      => 1.gigabyte,
    )

    @flavor.ext_management_system.should == @ems
  end

  def assert_specific_az
    @nova_az = AvailabilityZoneOpenstack.where(:type => AvailabilityZoneOpenstack, :ems_id => @ems.id).first
    # standard openstack AZs have their ems_ref set to their name ("nova" in the test case)...
    # the "null" openstack AZ has a unique ems_ref and name
    @nova_az.should have_attributes(
      :ems_ref => @nova_az.name
    )
  end

  def assert_availability_zone_null
    @az_null = AvailabilityZoneOpenstackNull.where(:ems_id => @ems.id).first
    @az_null.should have_attributes(
      :ems_ref => "null_az"
    )
  end

  def assert_specific_tenant
    @tenant = CloudTenant.where(:name => "admin").first
    @tenant.should be_kind_of(CloudTenant)
    @tenant.should have_attributes(
      :name        => "admin",
      :description => "admin tenant",
    )
  end

  def assert_specific_floating_ip
    @ip = FloatingIpOpenstack.where(:address => "10.8.97.2").first
    @ip.should have_attributes(
      :address => "10.8.97.2",
    )
    @ip.ems_ref.should be_guid
  end

  def assert_specific_key_pair
    @kp = AuthKeyPairOpenstack.where(:name => "EmsRefreshSpec-KeyPair").first
    @kp.should have_attributes(
      :name        => "EmsRefreshSpec-KeyPair",
      :fingerprint => "1d:e2:f2:f4:05:0c:d5:00:95:c5:78:22:9f:89:61:a5"
    )
  end

  def assert_specific_security_group
    @sg = SecurityGroupOpenstack.where(:name => "EmsRefreshSpec-SecurityGroup").first
    @sg.should have_attributes(
      :name        => "EmsRefreshSpec-SecurityGroup",
      :description => "EmsRefreshSpec-SecurityGroup description",
    )
    @sg.ems_ref.should be_guid

    expected_firewall_rules = [
      {:ems_ref => "0244ea29-567f-4a2e-bd92-d9a6b4716aa8",  :direction => "inbound",  :host_protocol => "TCP",  :network_protocol => "IPV6",  :port => 443, :end_port => 443,   :source_security_group => nil,  :source_ip_range => "::/0"},
      {:ems_ref => "0f07b773-78e7-443c-9aac-492ea8dcfc86",  :direction => "outbound", :host_protocol => "TCP",  :network_protocol => "IPV4",  :port => 443, :end_port => 443,   :source_security_group => nil,  :source_ip_range => "1.2.3.4/30"},
      {:ems_ref => "343185c7-a1a0-4ae1-8888-7266690afcdc",  :direction => "outbound", :host_protocol => "",     :network_protocol => "IPV6",  :port => nil, :end_port => nil,   :source_security_group => nil,  :source_ip_range => nil},
      {:ems_ref => "3e1053d7-8837-4d44-b0aa-d03eafad0994",  :direction => "inbound",  :host_protocol => "TCP",  :network_protocol => "IPV4",  :port => 80,  :end_port => 80,    :source_security_group => nil,  :source_ip_range => nil},
      {:ems_ref => "4e72f799-82b0-4471-ac13-a1e81b3dd437",  :direction => "outbound", :host_protocol => "TCP",  :network_protocol => "IPV6",  :port => 443, :end_port => 443,   :source_security_group => nil,  :source_ip_range => nil},
      {:ems_ref => "5600ec2a-3ee1-45c5-adcc-4a3bf0e9ef1a",  :direction => "inbound",  :host_protocol => "UDP",  :network_protocol => "IPV4",  :port => 1,   :end_port => 2,     :source_security_group => nil,  :source_ip_range => "1.2.3.4/30"},
      {:ems_ref => "70050d65-5df4-4ffa-92b3-278ea35f0110",  :direction => "inbound",  :host_protocol => "UDP",  :network_protocol => "IPV4",  :port => 3,   :end_port => 4,     :source_security_group => nil,  :source_ip_range => nil},
      {:ems_ref => "71360dcb-ef62-4f26-9f7c-7b333c4ef1aa",  :direction => "inbound",  :host_protocol => "TCP",  :network_protocol => "IPV4",  :port => 1,   :end_port => 2,     :source_security_group => nil,  :source_ip_range => "1.2.3.4/30"},
      {:ems_ref => "7d665b5c-71ec-4caf-b16e-a3d31c1afa89",  :direction => "inbound",  :host_protocol => "TCP",  :network_protocol => "IPV4",  :port => 1,   :end_port => 65535, :source_security_group => nil,  :source_ip_range => "0.0.0.0/0"},
      {:ems_ref => "860daea9-3c56-4389-83f8-576eacd1d64c",  :direction => "inbound",  :host_protocol => "TCP",  :network_protocol => "IPV4",  :port => 80,  :end_port => 80,    :source_security_group => nil,  :source_ip_range => "0.0.0.0/0"},
      {:ems_ref => "8ba56fac-3ac5-4ac9-9876-75b081e68f65",  :direction => "inbound",  :host_protocol => "UDP",  :network_protocol => "IPV4",  :port => 1,   :end_port => 65535, :source_security_group => nil,  :source_ip_range => "0.0.0.0/0"},
      {:ems_ref => "945bd0f2-bb25-4a69-ad97-dabcc095c802",  :direction => "inbound",  :host_protocol => "ICMP", :network_protocol => "IPV4",  :port => nil, :end_port => nil,   :source_security_group => nil,  :source_ip_range => nil},
      {:ems_ref => "a45689a3-cd1c-4b35-a173-eee7d4e7afa7",  :direction => "inbound",  :host_protocol => "ICMP", :network_protocol => "IPV4",  :port => nil, :end_port => nil,   :source_security_group => nil,  :source_ip_range => "1.2.3.4/30"},
      {:ems_ref => "cd8e3183-789a-4de3-ad01-ee67c32e19ff",  :direction => "outbound", :host_protocol => "TCP",  :network_protocol => "IPV6",  :port => 443, :end_port => 443,   :source_security_group => nil,  :source_ip_range => "::/0"},
      {:ems_ref => "d2f6a11c-fa84-4548-8ec6-fdd1d73e51c2",  :direction => "inbound",  :host_protocol => "TCP",  :network_protocol => "IPV6",  :port => 443, :end_port => 443,   :source_security_group => nil,  :source_ip_range => nil},
      {:ems_ref => "efe68717-c38e-439b-9be6-f5e178ae4db1",  :direction => "outbound", :host_protocol => "",     :network_protocol => "IPV4",  :port => nil, :end_port => nil,   :source_security_group => nil,  :source_ip_range => nil},
      {:ems_ref => "f1de106e-2f20-4649-9861-d1261e491957",  :direction => "inbound",  :host_protocol => "TCP",  :network_protocol => "IPV4",  :port => 80,  :end_port => 80,    :source_security_group => nil,  :source_ip_range => "1.2.3.4/30"},
      {:ems_ref => "f3b2041c-d836-4768-840e-6fdf9faeafaa",  :direction => "inbound",  :host_protocol => "TCP",  :network_protocol => "IPV4",  :port => 3,   :end_port => 4,     :source_security_group => nil,  :source_ip_range => nil},
      {:ems_ref => "f8557b54-e8ad-4bc0-9f21-537e746ea5b8",  :direction => "inbound",  :host_protocol => "TCP",  :network_protocol => "IPV6",  :port => 443, :end_port => 443,   :source_security_group => nil,  :source_ip_range => "0001:0002:0003:0004:0005:0006:0007:abc8/128"},
      {:ems_ref => "f933b0fe-f296-4994-9296-2621645a4c2a",  :direction => "inbound",  :host_protocol => "ICMP", :network_protocol => "IPV4",  :port => nil, :end_port => nil,   :source_security_group => nil,  :source_ip_range => "0.0.0.0/0"},
     ]

    @sg.firewall_rules.size.should == expected_firewall_rules.length
    @sg.firewall_rules.sort_by(&:ems_ref).zip(expected_firewall_rules).each do |actual, expected|
      actual.should have_attributes(expected)
    end
  end

  def assert_specific_network
    @net = CloudNetwork.where(:name => "EmsRefreshSpec-NetworkPrivate").first
    @net.should have_attributes(
      :name            => "EmsRefreshSpec-NetworkPrivate",
      :status          => "active",
      :enabled         => true,
      :external_facing => false,
    )
    @net.ems_ref.should be_guid

    # openstack subnets allow multiple records with the same cidr, and only the
    # id (ems_ref), cidr, and network_protocol are required fields in the
    # openstack mysql db ... have to keep ems_ref here in order to support
    # sorting/comparing below
    expected_subnets = [{
      :name             => "EmsRefreshSpec-SubnetPrivate",
      :ems_ref          => "faacd7ee-da56-464a-8d98-a243eedf698d",
      :cloud_network_id => @net.id,
      :cidr             => "192.168.0.0/24",
      :network_protocol => "ipv4",
      :gateway          => "192.168.0.1"
    }]

    @net.cloud_subnets.size.should == 1
    @net.cloud_subnets.order(:ems_ref).zip(expected_subnets).each do |actual, expected|
      actual.should have_attributes(expected)
    end
  end

  def assert_specific_private_template
    @template = assert_specific_template("EmsRefreshSpec-Image", "f163ac1a-57f9-4a2a-beca-12bc28e3ff78")
  end

  def assert_specific_public_template
    assert_specific_template("cirros", "20fa4213-0c13-4d0c-8a73-c80479ca1b21", true)
  end

  def assert_specific_template(name, uid, is_public = false)
    template = TemplateOpenstack.where(:name => name).first
    template.should have_attributes(
      :template              => true,
      :publicly_available    => is_public,
      :ems_ref_obj           => nil,
      :uid_ems               => uid,
      :vendor                => "OpenStack",
      :power_state           => "never",
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
    template.ems_ref.should be_guid

    template.ext_management_system.should  == @ems
    template.operating_system.should       be_nil # TODO: This should probably not be nil
    template.custom_attributes.size.should == 0
    template.snapshots.size.should         == 0
    template.hardware.should               be_nil

    template.parent.should                 be_nil
    template
  end

  def assert_specific_vm_powered_on
    @vm = VmOpenstack.where(:name => "EmsRefreshSpec-PoweredOn").first
    @vm.should have_attributes(
      :template              => false,
      :ems_ref_obj           => nil,
      :vendor                => "OpenStack",
      :power_state           => "off",
      :location              => "unknown",
      :tools_status          => nil,
      :boot_time             => nil,
      :standby_action        => nil,
      :connection_state      => "connected",
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
    @vm.ems_ref.should be_guid
    @vm.uid_ems.should be_guid

    @vm.ext_management_system.should  == @ems
    @vm.availability_zone.should      == @nova_az
    @vm.floating_ip.should            == @ip
    @vm.flavor.should                 == @flavor
    @vm.key_pairs.should              == [@kp]
    @vm.security_groups.should        match_array [@sg, SecurityGroup.where(:name => "EmsRefreshSpec-SecurityGroup2").first]

    @vm.operating_system.should       be_nil # TODO: This should probably not be nil
    @vm.custom_attributes.size.should == 0
    @vm.snapshots.size.should         == 0

    @vm.hardware.should have_attributes(
      :numvcpus      => 1,
      :memory_cpu    => 1024, # MB
      :disk_capacity => 2.5.gigabytes
    )

    @vm.hardware.disks.size.should == 3
    disk = @vm.hardware.disks.find_by_device_name("Root disk")
    disk.should have_attributes(
      :device_name => "Root disk",
      :device_type => "disk",
      :size        => 1.gigabyte,
    )
    disk = @vm.hardware.disks.find_by_device_name("Ephemeral disk")
    disk.should have_attributes(
      :device_name => "Ephemeral disk",
      :device_type => "disk",
      :size        => 1.gigabyte,
    )
    disk = @vm.hardware.disks.find_by_device_name("Swap disk")
    disk.should have_attributes(
      :device_name => "Swap disk",
      :device_type => "disk",
      :size        => 512.megabytes,
    )

    @vm.hardware.networks.size.should == 2
    network_public = @vm.hardware.networks.where(:description => "public").first
    network_public.should have_attributes(
      :description => "public",
      :ipaddress   => @ip.address,
    )

    network_private = @vm.hardware.networks.where(:description => "private").first
    network_private.should have_attributes(
      :description => "private",
      :ipaddress   => "192.168.0.2",
    )

    @vm.with_relationship_type("genealogy") do
      @vm.parent.should == @template
    end
  end

  def assert_specific_template_created_from_vm
    @snap = TemplateOpenstack.where(:name => "EmsRefreshSpec-Snapshot").first
    @snap.should_not be_nil
    #FIXME: @snap.parent.should == @vm
  end

  def assert_specific_vm_created_from_snapshot_template
    t = VmOpenstack.where(:name => "EmsRefreshSpec-PoweredOn-FromSnapshot").first
    t.parent.should == @snap
  end

  def assert_specific_vm_paused
    v = VmOpenstack.where(:name => "EmsRefreshSpec-Paused").first
    v.should have_attributes(
      :template              => false,
      :ems_ref_obj           => nil,
      :vendor                => "OpenStack",
      :power_state           => "paused",
      :location              => "unknown",
      :tools_status          => nil,
      :boot_time             => nil,
      :standby_action        => nil,
      :connection_state      => "connected",
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
    v.ems_ref.should be_guid
    v.uid_ems.should be_guid

    v.ext_management_system.should  == @ems
    v.availability_zone.should      == @nova_az
    v.floating_ip.should            be_nil
    v.flavor.should                 == @flavor
    v.key_pairs.should              == [@kp]
    v.security_groups.should        == [@sg]

    v.operating_system.should       be_nil # TODO: This should probably not be nil
    v.custom_attributes.size.should == 0
    v.snapshots.size.should         == 0

    v.hardware.should have_attributes(
      :numvcpus      => 1,
      :memory_cpu    => 1024, # MB
      :disk_capacity => 2.5.gigabytes
    )

    v.hardware.disks.size.should == 3
    disk = v.hardware.disks.find_by_device_name("Root disk")
    disk.should have_attributes(
      :device_name => "Root disk",
      :device_type => "disk",
      :size        => 1.gigabyte,
    )
    disk = v.hardware.disks.find_by_device_name("Ephemeral disk")
    disk.should have_attributes(
      :device_name => "Ephemeral disk",
      :device_type => "disk",
      :size        => 1.gigabyte,
    )
    disk = v.hardware.disks.find_by_device_name("Swap disk")
    disk.should have_attributes(
      :device_name => "Swap disk",
      :device_type => "disk",
      :size        => 512.megabytes,
    )

    v.hardware.networks.size.should == 1
    network = v.hardware.networks.where(:description => "private").first
    network.should have_attributes(
      :description => "private",
      :ipaddress   => "192.168.0.5",
    )

    v.with_relationship_type("genealogy") do
      v.parent.should == @template
    end
  end

  def assert_specific_vm_suspended
    v = VmOpenstack.where(:name => "EmsRefreshSpec-Suspended").first
    v.should have_attributes(
      :template              => false,
      :ems_ref_obj           => nil,
      :vendor                => "OpenStack",
      :power_state           => "suspended",
      :raw_power_state       => "SUSPENDED",
      :location              => "unknown",
      :tools_status          => nil,
      :boot_time             => nil,
      :standby_action        => nil,
      :connection_state      => "connected",
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
    v.ems_ref.should be_guid
    v.uid_ems.should be_guid

    v.ext_management_system.should  == @ems
    v.availability_zone.should      == @nova_az
    v.floating_ip.should            be_nil
    v.flavor.should                 == @flavor
    v.key_pairs.should              == [@kp]
    v.security_groups.should        == [@sg]

    v.operating_system.should       be_nil # TODO: This should probably not be nil
    v.custom_attributes.size.should == 0
    v.snapshots.size.should         == 0

    v.hardware.should have_attributes(
      :numvcpus      => 1,
      :memory_cpu    => 1024, # MB
      :disk_capacity => 2.5.gigabytes
    )

    v.hardware.disks.size.should == 3
    disk = v.hardware.disks.find_by_device_name("Root disk")
    disk.should have_attributes(
      :device_name => "Root disk",
      :device_type => "disk",
      :size        => 1.gigabyte,
    )
    disk = v.hardware.disks.find_by_device_name("Ephemeral disk")
    disk.should have_attributes(
      :device_name => "Ephemeral disk",
      :device_type => "disk",
      :size        => 1.gigabyte,
    )
    disk = v.hardware.disks.find_by_device_name("Swap disk")
    disk.should have_attributes(
      :device_name => "Swap disk",
      :device_type => "disk",
      :size        => 512.megabytes,
    )

    v.hardware.networks.size.should == 1
    network = v.hardware.networks.where(:description => "private").first
    network.should have_attributes(
      :description => "private",
      :ipaddress   => "192.168.0.6",
    )

    v.with_relationship_type("genealogy") do
      v.parent.should == @template
    end
  end

  def assert_relationship_tree
    @ems.descendants_arranged.should match_relationship_tree({})
  end
end
