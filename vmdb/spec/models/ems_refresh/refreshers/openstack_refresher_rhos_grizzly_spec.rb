require "spec_helper"

describe EmsRefresh::Refreshers::OpenstackRefresher do
  before(:each) do
    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_openstack, :zone => zone, :hostname => "1.2.3.4", :ipaddress => "1.2.3.4", :port => 5000)
    @ems.update_authentication(:default => {:userid => "admin", :password => "password"})
  end

  it "will perform a full refresh against RHOS Grizzly" do
    2.times do  # Run twice to verify that a second run with existing data does not change anything
      @ems.reload
      # Caching OpenStack info between runs causes the tests to fail with:
      #   VCR::Errors::UnusedHTTPInteractionError
      # Reset the cache so HTTP interactions are the same between runs.
      @ems.reset_openstack_handle

      # We need VCR to match requests differently here because fog adds a dynamic
      #   query param to avoid HTTP caching - ignore_awful_caching##########
      #   https://github.com/fog/fog/blob/master/lib/fog/openstack/compute.rb#L308
      VCR.use_cassette("#{described_class.name.underscore}_rhos_grizzly",
                       :allow_unused_http_interactions => false,  # don't rely on default (differs, local vs Travis)
                       :match_requests_on              => [:method, :host, :path]) do
        EmsRefresh.refresh(@ems)
      end
      @ems.reload

      assert_table_counts
      assert_ems
      # assert_specific_host
      assert_specific_flavor
      assert_specific_az
      assert_availability_zone_null
      assert_specific_floating_ip
      assert_specific_key_pair
      assert_specific_security_group
      assert_specific_template
      assert_specific_vm_powered_on
      assert_specific_template_created_from_vm
      assert_specific_vm_created_from_snapshot_template
      assert_specific_vm_paused
      assert_specific_vm_suspended
      assert_relationship_tree
    end
  end

  def assert_table_counts
    ExtManagementSystem.count.should == 1
    Flavor.count.should              == 11
    AvailabilityZone.count.should    == 2 # nova AZ and null_az
    FloatingIp.count.should          == 10
    AuthPrivateKey.count.should      == 1
    SecurityGroup.count.should       == 7
    FirewallRule.count.should        == 12
    CloudNetwork.count.should        == 0
    CloudSubnet.count.should         == 0
    VmOrTemplate.count.should        == 18
    Vm.count.should                  == 10
    MiqTemplate.count.should         == 8

    CustomAttribute.count.should     == 0
    Disk.count.should                == 16
    GuestDevice.count.should         == 0
    Hardware.count.should            == 10
    Network.count.should             == 11
    OperatingSystem.count.should     == 0
    Snapshot.count.should            == 0
    SystemService.count.should       == 0

    Relationship.count.should        == 15
    MiqQueue.count.should            == 20
  end

  def assert_ems
    @ems.should have_attributes(
      :api_version => nil, # TODO: Should be 2.0?
      :uid_ems     => nil
    )

    @ems.flavors.size.should            == 11
    @ems.availability_zones.size.should == 2 #null AZ and nova az
    @ems.floating_ips.size.should       == 10
    @ems.key_pairs.size.should          == 1
    @ems.security_groups.size.should    == 7
    @ems.vms_and_templates.size.should  == 18
    @ems.vms.size.should                == 10
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
    @flavor = Flavor.where(:name => "m1.ems_refresh_spec").first
    @flavor.should be_kind_of(FlavorOpenstack)
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

  def assert_specific_floating_ip
    @ip = FloatingIp.where(:address => "10.3.4.1").first
    @ip.should be_kind_of(FloatingIpOpenstack)
    @ip.should have_attributes(
      :address => "10.3.4.1",
      :ems_ref => "1"
    )
  end

  def assert_specific_key_pair
    @kp = AuthPrivateKey.where(:name => "EmsRefreshSpec-KeyPair").first
    @kp.should have_attributes(
      :name        => "EmsRefreshSpec-KeyPair",
      :fingerprint => "5e:51:73:2d:71:14:94:34:97:4c:e8:e5:92:49:9e:9e"
    )
  end

  def assert_specific_security_group
    @sg = SecurityGroup.where(:name => "EmsRefreshSpec-SecurityGroup").first
    @sg.should have_attributes(
      :name        => "EmsRefreshSpec-SecurityGroup",
      :description => "EmsRefreshSpec-SecurityGroup",
      :ems_ref     => "4"
    )

    expected_firewall_rules = [
      {:ems_ref=>"1",  :direction=>"inbound", :host_protocol=>"TCP",  :network_protocol=>nil, :port=>1,  :end_port=>2,     :source_ip_range=>"1.2.3.4/30", :source_security_group_id => nil},
      {:ems_ref=>"10", :direction=>"inbound", :host_protocol=>"ICMP", :network_protocol=>nil, :port=>0,  :end_port=>-1,    :source_ip_range=>"1.2.3.4/30", :source_security_group_id => nil},
      {:ems_ref=>"12", :direction=>"inbound", :host_protocol=>"ICMP", :network_protocol=>nil, :port=>-1, :end_port=>-1,    :source_ip_range=>nil,          :source_security_group_id => @sg.id},
      {:ems_ref=>"13", :direction=>"inbound", :host_protocol=>"ICMP", :network_protocol=>nil, :port=>-1, :end_port=>-1,    :source_ip_range=>"0.0.0.0/0",  :source_security_group_id => nil},
      {:ems_ref=>"2",  :direction=>"inbound", :host_protocol=>"TCP",  :network_protocol=>nil, :port=>1,  :end_port=>65535, :source_ip_range=>"0.0.0.0/0",  :source_security_group_id => nil},
      {:ems_ref=>"3",  :direction=>"inbound", :host_protocol=>"TCP",  :network_protocol=>nil, :port=>3,  :end_port=>4,     :source_ip_range=>nil,          :source_security_group_id => @sg.id},
      {:ems_ref=>"4",  :direction=>"inbound", :host_protocol=>"TCP",  :network_protocol=>nil, :port=>80, :end_port=>80,    :source_ip_range=>"1.2.3.4/30", :source_security_group_id => nil},
      {:ems_ref=>"5",  :direction=>"inbound", :host_protocol=>"TCP",  :network_protocol=>nil, :port=>80, :end_port=>80,    :source_ip_range=>"0.0.0.0/0",  :source_security_group_id => nil},
      {:ems_ref=>"6",  :direction=>"inbound", :host_protocol=>"TCP",  :network_protocol=>nil, :port=>80, :end_port=>80,    :source_ip_range=>nil,          :source_security_group_id => @sg.id},
      {:ems_ref=>"7",  :direction=>"inbound", :host_protocol=>"UDP",  :network_protocol=>nil, :port=>1,  :end_port=>2,     :source_ip_range=>"1.2.3.4/30", :source_security_group_id => nil},
      {:ems_ref=>"8",  :direction=>"inbound", :host_protocol=>"UDP",  :network_protocol=>nil, :port=>1,  :end_port=>65535, :source_ip_range=>"0.0.0.0/0",  :source_security_group_id => nil},
      {:ems_ref=>"9",  :direction=>"inbound", :host_protocol=>"UDP",  :network_protocol=>nil, :port=>3,  :end_port=>4,     :source_ip_range=>nil,          :source_security_group_id => @sg.id},
    ]

    @sg.firewall_rules.size.should == expected_firewall_rules.length
    @sg.firewall_rules.sort_by(&:ems_ref).zip(expected_firewall_rules).each do |actual, expected|
      actual.should have_attributes(expected)
    end
  end

  def assert_specific_template
    @template = MiqTemplate.where(:name => "EmsRefreshSpec-Image").first
    @template.should have_attributes(
      :template              => true,
      :ems_ref               => "a11384ef-a7d1-4c99-b063-dd60a357d3ff",
      :ems_ref_obj           => nil,
      :uid_ems               => "a11384ef-a7d1-4c99-b063-dd60a357d3ff",
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

    @template.ext_management_system.should  == @ems
    @template.operating_system.should       be_nil # TODO: This should probably not be nil
    @template.custom_attributes.size.should == 0
    @template.snapshots.size.should         == 0
    @template.hardware.should               be_nil

    @template.parent.should                 be_nil
  end

  def assert_specific_vm_powered_on
    @vm = Vm.where(:name => "EmsRefreshSpec-PoweredOn").first
    @vm.should have_attributes(
      :template              => false,
      :ems_ref               => "4bb8d624-a3a5-421c-9e14-8a6eaa16aed8",
      :ems_ref_obj           => nil,
      :uid_ems               => "4bb8d624-a3a5-421c-9e14-8a6eaa16aed8",
      :vendor                => "OpenStack",
      :power_state           => "on",
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
    network = @vm.hardware.networks.where(:description => "public").first
    network.should have_attributes(
      :description => "public",
      :ipaddress   => @ip.address,
    )
    network = @vm.hardware.networks.where(:description => "private").first
    network.should have_attributes(
      :description => "private",
      :ipaddress   => "192.168.32.6",
    )

    @vm.with_relationship_type("genealogy") do
      @vm.parent.should == @template
    end
  end

  def assert_specific_template_created_from_vm
    @snap = MiqTemplate.where(:name => "EmsRefreshSpec-Snapshot").first
    @snap.should_not be_nil
    #FIXME: @snap.parent.should == @vm
  end

  def assert_specific_vm_created_from_snapshot_template
    t = Vm.where(:name => "EmsRefreshSpec-PoweredOn-FromSnapshot").first
    t.parent.should == @snap
  end

  def assert_specific_vm_paused
    v = Vm.where(:name => "EmsRefreshSpec-Paused").first
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "83de8005-7138-4005-b4a9-980d0df622ff",
      :ems_ref_obj           => nil,
      :uid_ems               => "83de8005-7138-4005-b4a9-980d0df622ff",
      :vendor                => "OpenStack",
      :power_state           => "suspended",
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
      :ipaddress   => "192.168.32.2",
    )

    v.with_relationship_type("genealogy") do
      v.parent.should == @template
    end
  end

  def assert_specific_vm_suspended
    v = Vm.where(:name => "EmsRefreshSpec-Suspended").first
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "ed1056c3-53b1-4cec-af88-a6e6a6be1d44",
      :ems_ref_obj           => nil,
      :uid_ems               => "ed1056c3-53b1-4cec-af88-a6e6a6be1d44",
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
      :ipaddress   => "192.168.32.8",
    )

    v.with_relationship_type("genealogy") do
      v.parent.should == @template
    end
  end

  def assert_relationship_tree
    @ems.descendants_arranged.should match_relationship_tree({})
  end
end
