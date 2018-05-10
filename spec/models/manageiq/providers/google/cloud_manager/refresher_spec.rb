require 'fog/google'

describe ManageIQ::Providers::Google::CloudManager::Refresher do
  let(:cloud_network)         { CloudNetwork.find_by(:name => "default") }
  let(:cloud_subnet)          { CloudSubnet.find_by(:name => "default") }
  let(:cloud_volume)          { CloudVolume.find_by(:name => "instance-group-1-gvej") }
  let(:cloud_volume_snapshot) { CloudVolumeSnapshot.find_by(:name => "test-snapshot-1") }
  let(:flavor)                { Flavor.find_by(:name => "n1-standard-1") }
  let(:floating_ip_1)         { FloatingIp.find_by(:address => "35.184.135.147") }
  let(:floating_ip_2)         { FloatingIp.find_by(:address => "35.194.238.83") }
  let(:floating_ip_3)         { FloatingIp.find_by(:address => "35.194.238.83") }
  let(:key_pair)              { AuthPrivateKey.find_by(:name => "gke-4866da88e59a4051ce37") }
  let(:load_balancer)         { LoadBalancer.find_by(:name => "test-first-load-balancer-forwarding-rule") }
  let(:security_group)        { SecurityGroup.find_by(:name => "lkhomenk-network") }
  let(:zone_central)          { AvailabilityZone.find_by(:ems_ref => "us-central1-a") }
  let(:zone_east)             { AvailabilityZone.find_by(:ems_ref => "us-east1-c") }
  let(:vm_powered_on)         { Vm.find_by(:name => "instance-group-1-gvej") }
  let(:vm_powered_off)        { Vm.find_by(:name => "simaishi-g3") }
  let(:vm_preemptible)        { Vm.find_by(:name => "preemptible") }
  let(:image_template)        { ManageIQ::Providers::Google::CloudManager::Template.find_by(:name => "rhel-7-v20180510") }
  let(:image_location)        { "https://www.googleapis.com/compute/v1/projects/rhel-cloud/global/images/rhel-7-v20180510" }
  let(:snapshot_template)     { ManageIQ::Providers::Google::CloudManager::Template.find_by(:name => "test-snapshot-1") }
  let(:snapshot_location)     { "https://www.googleapis.com/compute/v1/projects/red-hat-cloudforms-support/global/snapshots/test-snapshot-1" }

  before(:each) do
    @ems = FactoryGirl.create(:ems_google_with_vcr_authentication)
  end

  MODELS = %i(
    availability_zone cloud_network cloud_subnet disk ext_management_system flavor floating_ip
    guest_device hardware load_balancer load_balancer_health_check load_balancer_health_check_member
    load_balancer_listener load_balancer_listener_pool load_balancer_pool load_balancer_pool_member
    load_balancer_pool_member_pool miq_template network network_port network_router operating_system
    orchestration_stack orchestration_stack_output orchestration_stack_parameter orchestration_stack_resource
    orchestration_template relationship resource_group security_group vm vm_or_template
  ).freeze

  it "will perform a full refresh" do
    2.times do # Run twice to verify that a second run with existing data does not change anything
      @ems.reload
      VCR.use_cassette(described_class.name.underscore, :allow_unused_http_interactions => true) do
        EmsRefresh.refresh(@ems)
        EmsRefresh.refresh(@ems.network_manager)
      end
      @ems.reload

      assert_table_counts
      assert_ems
      assert_specific_zone
      assert_specific_key_pair
      assert_specific_cloud_network
      assert_specific_cloud_subnet
      assert_specific_floating_ips
      assert_specific_load_balancer
      assert_specific_security_group
      assert_specific_flavor
      assert_specific_vm_powered_on
      assert_specific_vm_powered_off
      assert_specific_vm_preemptible
      assert_specific_image_template
      assert_specific_snapshot_template
      assert_specific_cloud_volume
      assert_specific_cloud_volume_snapshot
    end
  end

  def expected_table_counts
    {
      :availability_zone                 => 46,
      :cloud_network                     => 3,
      :cloud_subnet                      => 18,
      :disk                              => 15,
      :ext_management_system             => 2,
      :flavor                            => 29,
      :floating_ip                       => 13,
      :guest_device                      => 0,
      :hardware                          => 15,
      :key_pair                          => 1,
      :load_balancer                     => 4,
      :load_balancer_health_check_member => 1,
      :load_balancer_health_check        => 1,
      :load_balancer_listener            => 4,
      :load_balancer_pool                => 3,
      :load_balancer_listener_pool       => 4,
      :load_balancer_pool_member         => 4,
      :load_balancer_pool_member_pool    => 4,
      :miq_template                      => 1631,
      :network                           => 0,
      :network_port                      => 15,
      :network_router                    => 0,
      :operating_system                  => 1643,
      :orchestration_stack               => 0,
      :orchestration_stack_output        => 0,
      :orchestration_stack_parameter     => 0,
      :orchestration_stack_resource      => 0,
      :orchestration_template            => 0,
      :relationship                      => 18,
      :resource_group                    => 0,
      :security_group                    => 3,
      :vm                                => 15,
      :vm_or_template                    => 1646,
    }
  end

  def assert_table_counts
    actual = Hash[MODELS.collect { |m| [m, m.to_s.classify.constantize.count] }]
    actual[:key_pair] = AuthPrivateKey.count

    expect(actual).to eq expected_table_counts
  end

  def assert_ems
    expect(@ems.flavors.size).to            eql(expected_table_counts[:flavor])
    expect(@ems.key_pairs.size).to          eql(expected_table_counts[:key_pair])
    expect(@ems.availability_zones.size).to eql(expected_table_counts[:availability_zone])
    expect(@ems.vms_and_templates.size).to  eql(expected_table_counts[:vm_or_template])
    expect(@ems.cloud_networks.size).to     eql(expected_table_counts[:cloud_network])
    expect(@ems.security_groups.size).to    eql(expected_table_counts[:security_group])
    expect(@ems.vms.size).to                eql(expected_table_counts[:vm])
    expect(@ems.miq_templates.size).to      eql(expected_table_counts[:miq_template])
  end

  def assert_specific_zone
    expect(zone_east).to have_attributes(
      :name   => "us-east1-c",
      :ems_id => @ems.id
    )

    expect(zone_central).to have_attributes(
      :name   => "us-central1-a",
      :ems_id => @ems.id
    )
  end

  def assert_specific_key_pair
    expect(key_pair).to have_attributes(
      :name        => "gke-4866da88e59a4051ce37",
      :fingerprint => "a5:09:ea:89:2b:82:63:66:0b:38:d0:78:a5:a5:02:fb:05:f4:4f:33"
    )
  end

  def assert_specific_cloud_network
    expect(cloud_network).to have_attributes(
      :name    => "default",
      :ems_ref => "7587328054479720388",
      :cidr    => nil,
      :status  => "active",
      :enabled => true
    )
  end

  def assert_specific_cloud_subnet
    expect(cloud_subnet).to have_attributes(
      :name             => "default",
      :ems_ref          => "3712394189059902205",
      :cidr             => "10.138.0.0/20",
      :gateway          => "10.138.0.1",
      :status           => "active",
      :cloud_network_id => cloud_network.id
    )
  end

  def assert_specific_floating_ips
    expect(floating_ip_1.vm).not_to eql(nil)
    expect(floating_ip_1.network_port.device).not_to eql(nil)

    expect(floating_ip_2.vm).to eql(nil)
    expect(floating_ip_2.network_port).to eql(nil)
  end

  def assert_specific_load_balancer
    expect(load_balancer).to have_attributes(
      :name    => "test-first-load-balancer-forwarding-rule",
      :ems_ref => "3192052763601282961",
      :type    => "ManageIQ::Providers::Google::NetworkManager::LoadBalancer"
    )
    expect(load_balancer.load_balancer_listeners.first).to have_attributes(
      :name                     => "test-first-load-balancer-forwarding-rule",
      :ems_ref                  => "3192052763601282961",
      :type                     => "ManageIQ::Providers::Google::NetworkManager::LoadBalancerListener",
      :load_balancer_protocol   => "TCP",
      :instance_protocol        => "TCP",
      :load_balancer_port_range => 80...81,
      :instance_port_range      => 80...81
    )
    expect(load_balancer.load_balancer_pools.first).to have_attributes(
      :name    => "test-first-load-balancer",
      :ems_ref => "9047195615959852949",
      :type    => "ManageIQ::Providers::Google::NetworkManager::LoadBalancerPool",
    )
    expect(load_balancer.load_balancer_pool_members.map { |m| m.vm.name }).to include("load-balancer-1")

    lb_health_check = load_balancer.load_balancer_health_checks.first
    expect(lb_health_check).to have_attributes(
      :name                => "test-lb-health-check",
      :type                => "ManageIQ::Providers::Google::NetworkManager::LoadBalancerHealthCheck",
      :ems_ref             => "3192052763601282961_9047195615959852949_5437000699954601152",
      :protocol            => "HTTP",
      :port                => 80,
      :url_path            => "/",
      :interval            => 5,
      :timeout             => 5,
      :healthy_threshold   => 2,
      :unhealthy_threshold => 2
    )
    expect(lb_health_check.load_balancer_health_check_members.first).to have_attributes(:status => "OutOfService")
    expect(lb_health_check.load_balancer_health_check_members.first.load_balancer_pool_member.vm.name).to eql("load-balancer-1")
  end

  def assert_specific_security_group
    expect(security_group).to have_attributes(
      :name    => "lkhomenk-network",
      :ems_ref => "lkhomenk-network"
    )

    expect(security_group.firewall_rules.size).to eq(1)
    expect(security_group.firewall_rules.first).to have_attributes(
      :name            => "some-rule",
      :host_protocol   => "ALL",
      :direction       => "inbound",
      :port            => -1,
      :end_port        => -1,
      :source_ip_range => "0.0.0.0/0"
    )
  end

  def assert_specific_flavor
    expect(flavor).to have_attributes(
      :name        => "n1-standard-1",
      :ems_ref     => "n1-standard-1",
      :description => "1 vCPU, 3.75 GB RAM",
      :enabled     => true,
      :cpus        => 1,
      :memory      => 4026531840
    )

    expect(flavor.ext_management_system).to eq(@ems)
  end

  def assert_specific_vm_powered_on
    expect(vm_powered_on).to have_attributes(
      :boot_time             => nil,
      :connection_state      => nil,
      :cpu_affinity          => nil,
      :cpu_limit             => nil,
      :cpu_reserve           => nil,
      :cpu_reserve_expand    => nil,
      :cpu_shares            => nil,
      :cpu_shares_level      => nil,
      :ems_ref               => "9028819323520596299",
      :ems_ref_obj           => nil,
      :location              => "unknown",
      :memory_limit          => nil,
      :memory_reserve        => nil,
      :memory_reserve_expand => nil,
      :memory_shares         => nil,
      :memory_shares_level   => nil,
      :power_state           => "on",
      :raw_power_state       => "RUNNING",
      :standby_action        => nil,
      :template              => false,
      :tools_status          => nil,
      :uid_ems               => "9028819323520596299",
      :vendor                => "google"
    )

    expect(vm_powered_on.ext_management_system).to         eql(@ems)
    expect(vm_powered_on.availability_zone).to             eql(zone_central)
    expect(vm_powered_on.flavor).to                        eql(flavor)
    expect(vm_powered_on.operating_system.product_name).to eql("linux_debian")
    expect(vm_powered_on.custom_attributes.size).to        eql(0)
    expect(vm_powered_on.snapshots.size).to                eql(0)
    expect(vm_powered_on.preemptible?).to                  eql(false)
    expect(vm_powered_on.key_pairs.first).to               eql(key_pair)

    assert_specific_vm_powered_on_hardware(vm_powered_on)
    assert_specific_vm_powered_on_hardware_disks(vm_powered_on)
    assert_specific_vm_powered_on_networks(vm_powered_on)
    assert_specific_vm_powered_on_floating_ips(vm_powered_on)
  end

  def assert_specific_vm_powered_on_hardware(v)
    expect(v.hardware).to have_attributes(
      :guest_os            => nil,
      :guest_os_full_name  => nil,
      :bios                => nil,
      :annotation          => nil,
      :cpu_total_cores     => 1,
      :memory_mb           => 3840,
      :bitness             => nil,
      :virtualization_type => nil
    )

    expect(v.hardware.guest_devices.size).to eql(0)
    expect(v.hardware.nics.size).to          eql(0)
  end

  def assert_specific_vm_powered_on_hardware_disks(v)
    expect(v.hardware.disks.size).to eql(1)

    disk = v.hardware.disks.first
    expect(disk).to have_attributes(
      :device_name     => "instance-template-1",
      :device_type     => "disk",
      :location        => "0",
      :controller_type => "google",
      :size            => 10.gigabyte,
      :backing_type    => "CloudVolume"
    )
    expect(disk.backing).to eql(cloud_volume)
  end

  def assert_specific_vm_powered_on_networks(v)
    expect(v.cloud_networks.size).to eql(1)
    expect(v.cloud_subnets.size).to  eql(1)
    expect(v.network_ports.size).to  eql(1)
    expect(v.ipaddresses.size).to    eql(2)

    expect(v.network_ports.first.ipaddresses.first).to eq('10.128.0.3')

    expect(v.cloud_networks.first).to have_attributes(:name => 'default')
    expect(v.cloud_networks.first).to eq(v.cloud_network)
    expect(v.cloud_subnets.first).to  have_attributes(:name => 'default-175e7dd38602e139')
    expect(v.cloud_subnets.first).to  eq(v.cloud_subnet)
  end

  def assert_specific_vm_powered_on_floating_ips(v)
    expect(v.floating_ips.size).to                      eql(1)
    expect(v.floating_ip).to                            eql(floating_ip_1)
    expect(v.floating_ips.first).to                     eql(floating_ip_1)
    expect(v.network_ports.first.floating_ip).to        eql(floating_ip_1)
    expect(v.network_ports.first.floating_ips.first).to eql(floating_ip_1)
  end

  def assert_specific_vm_powered_off
    expect(vm_powered_off).to have_attributes(
      :boot_time             => nil,
      :connection_state      => nil,
      :cpu_affinity          => nil,
      :cpu_limit             => nil,
      :cpu_reserve           => nil,
      :cpu_reserve_expand    => nil,
      :cpu_shares            => nil,
      :cpu_shares_level      => nil,
      :ems_ref               => "3801021534917226736",
      :ems_ref_obj           => nil,
      :location              => "unknown",
      :memory_limit          => nil,
      :memory_reserve        => nil,
      :memory_reserve_expand => nil,
      :memory_shares         => nil,
      :memory_shares_level   => nil,
      :power_state           => "off",
      :raw_power_state       => "TERMINATED",
      :standby_action        => nil,
      :template              => false,
      :tools_status          => nil,
      :uid_ems               => "3801021534917226736",
      :vendor                => "google"
    )

    expect(vm_powered_off.ext_management_system).to         eql(@ems)
    expect(vm_powered_off.availability_zone).to             eql(zone_east)
    expect(vm_powered_off.flavor).to                        eql(flavor)
    expect(vm_powered_off.operating_system.product_name).to eql("unknown")
    expect(vm_powered_off.custom_attributes.size).to        eql(0)
    expect(vm_powered_off.snapshots.size).to                eql(0)
    expect(vm_powered_off.preemptible?).to                  eql(false)
    expect(vm_powered_off.key_pairs.first).to               eql(key_pair)

    assert_specific_vm_powered_off_hardware(vm_powered_off)
    assert_specific_vm_powered_off_hardware_disks(vm_powered_off)
    assert_specific_vm_powered_off_networks(vm_powered_off)
    assert_specific_vm_powered_off_floating_ips(vm_powered_off)
  end

  def assert_specific_vm_powered_off_hardware(v)
    expect(v.hardware).to have_attributes(
      :guest_os            => nil,
      :guest_os_full_name  => nil,
      :bios                => nil,
      :annotation          => nil,
      :cpu_total_cores     => 1,
      :memory_mb           => 3840,
      :bitness             => nil,
      :virtualization_type => nil
    )

    expect(v.hardware.guest_devices.size).to eql(0)
    expect(v.hardware.nics.size).to          eql(0)
  end

  def assert_specific_vm_powered_off_hardware_disks(v)
    expect(v.hardware.disks.size).to eql(1)

    disk = v.hardware.disks.first
    expect(disk).to have_attributes(
      :device_name     => "simaishi-g3",
      :device_type     => "disk",
      :location        => "0",
      :controller_type => "google",
      :size            => 66.gigabyte,
      :backing_type    => "CloudVolume"
    )

    expect(disk.backing).to have_attributes(:name => "simaishi-g3")
  end

  def assert_specific_vm_powered_off_networks(v)
    expect(v.cloud_networks.size).to eql(1)
    expect(v.cloud_subnets.size).to  eql(1)
    expect(v.network_ports.size).to  eql(1)
    expect(v.ipaddresses.size).to    eql(1)

    expect(v.network_ports.first.ipaddresses.first).to eq('10.142.0.6')

    expect(v.cloud_networks.first).to have_attributes(:name => 'default')
    expect(v.cloud_networks.first).to eq(v.cloud_network)
    expect(v.cloud_subnets.first).to  have_attributes(:name => 'default-372dec1aa369576e')
    expect(v.cloud_subnets.first).to  eq(v.cloud_subnet)
  end

  def assert_specific_vm_powered_off_floating_ips(v)
    expect(v.floating_ips.size).to                      eql(0)
    expect(v.floating_ip).to                            eql(nil)
    expect(v.floating_ips.first).to                     eql(nil)
    expect(v.network_ports.first.floating_ip).to        eql(nil)
    expect(v.network_ports.first.floating_ips.first).to eql(nil)
  end

  def assert_specific_vm_preemptible
    expect(vm_preemptible).to have_attributes(
      :raw_power_state => "TERMINATED",
      :template        => false,
      :ems_ref         => "8920424377663102465",
      :uid_ems         => "8920424377663102465",
      :vendor          => "google",
      :power_state     => "off"
    )

    expect(vm_preemptible.preemptible?).to eql(true)
  end

  def assert_specific_image_template
    expect(image_template).to have_attributes(
      :template              => true,
      :ems_ref               => "532520468831844769",
      :ems_ref_obj           => nil,
      :uid_ems               => "532520468831844769",
      :vendor                => "google",
      :power_state           => "never",
      :location              => image_location,
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

    expect(image_template.ext_management_system).to         eq(@ems)
    expect(image_template.operating_system.product_name).to eq("linux_redhat")
    expect(image_template.custom_attributes.size).to        eq(0)
    expect(image_template.snapshots.size).to                eq(0)
  end

  def assert_specific_snapshot_template
    expect(snapshot_template).to have_attributes(
      :template              => true,
      :ems_ref               => "4530445150875817520",
      :ems_ref_obj           => nil,
      :uid_ems               => "4530445150875817520",
      :vendor                => "google",
      :power_state           => "never",
      :location              => snapshot_location,
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

    expect(snapshot_template.ext_management_system).to         eq(@ems)
    expect(snapshot_template.operating_system.product_name).to eq("unknown")
    expect(snapshot_template.custom_attributes.size).to        eq(0)
    expect(snapshot_template.snapshots.size).to                eq(0)
  end

  def assert_specific_cloud_volume
    expect(cloud_volume).to have_attributes(
      :ems_ref           => "1368210998906894667",
      :name              => "instance-group-1-gvej",
      :status            => "READY",
      :volume_type       => "pd-standard",
      :description       => nil,
      :size              => 10.gigabyte,
      :availability_zone => zone_central
    )
    expect(cloud_volume.creation_time.to_s).to eql("2017-05-05 23:15:49 UTC")
  end

  def assert_specific_cloud_volume_snapshot
    expect(cloud_volume_snapshot).to have_attributes(
      :name        => "test-snapshot-1",
      :ems_ref     => "4530445150875817520",
      :status      => "READY",
      :description => nil,
      :encrypted   => nil,
      :size        => 10.gigabyte
    )
    expect(cloud_volume_snapshot.creation_time.to_s).to eql("2018-05-11 14:29:52 UTC")
  end
end
