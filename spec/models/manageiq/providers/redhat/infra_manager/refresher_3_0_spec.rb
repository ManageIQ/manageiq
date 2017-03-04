describe ManageIQ::Providers::Redhat::InfraManager::Refresher do
  let(:ip_address) { '192.168.252.231' }

  before(:each) do
    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_redhat, :zone => zone, :hostname => ip_address, :ipaddress => ip_address, :port => 8443)
    @ems.update_authentication(:default => {:userid => "evm@manageiq.com", :password => "password"})
    allow(@ems).to receive(:supported_api_versions).and_return([3])
    allow(@ems).to receive(:resolve_ip_address).with(ip_address).and_return(ip_address)
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:rhevm)
  end

  it "will perform a full refresh on v3.0" do
    VCR.use_cassette("#{described_class.name.underscore}_3_0") do
      EmsRefresh.refresh(@ems)
    end
    @ems.reload

    assert_table_counts
    assert_ems
    assert_specific_cluster
    assert_specific_storage
    assert_specific_host
    assert_specific_vm_powered_on
    assert_specific_vm_powered_off
    assert_specific_template
    assert_relationship_tree
  end

  def assert_table_counts
    expect(ExtManagementSystem.count).to eq(1)
    expect(EmsFolder.count).to eq(10)
    expect(EmsCluster.count).to eq(5)
    expect(Host.count).to eq(1)
    expect(ResourcePool.count).to eq(5)
    expect(VmOrTemplate.count).to eq(35)
    expect(Vm.count).to eq(21)
    expect(MiqTemplate.count).to eq(14)
    expect(Storage.count).to eq(6)

    expect(CustomAttribute.count).to eq(3)
    expect(CustomizationSpec.count).to eq(0)
    expect(Disk.count).to eq(124)
    expect(GuestDevice.count).to eq(26)
    expect(Hardware.count).to eq(36)
    expect(Lan.count).to eq(2)
    expect(MiqScsiLun.count).to eq(0)
    expect(MiqScsiTarget.count).to eq(0)
    expect(Network.count).to eq(2)
    expect(OperatingSystem.count).to eq(36)
    expect(Snapshot.count).to eq(41)
    expect(Switch.count).to eq(2)
    expect(SystemService.count).to eq(0)

    expect(Relationship.count).to eq(77)
    # MiqQueue.count.should            == 35 #PENDING: Some timing issue keeps flipping this between 35 and 36
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :api_version => "3.0.0.0",
      :uid_ems     => nil
    )

    expect(@ems.ems_folders.size).to eq(10)
    expect(@ems.ems_clusters.size).to eq(5)
    expect(@ems.resource_pools.size).to eq(5)
    expect(@ems.storages.size).to eq(2) # TODO: The table count is 6, but this is 4 ??
    expect(@ems.hosts.size).to eq(1)
    expect(@ems.vms_and_templates.size).to eq(35)
    expect(@ems.vms.size).to eq(21)
    expect(@ems.miq_templates.size).to eq(14)

    expect(@ems.customization_specs.size).to eq(0)
  end

  def assert_specific_cluster
    @cluster = EmsCluster.find_by_name("Cluster2")
    expect(@cluster).to have_attributes(
      :ems_ref                 => "/api/clusters/40c1c666-e919-11e0-9c6b-005056af0085",
      :ems_ref_obj             => "/api/clusters/40c1c666-e919-11e0-9c6b-005056af0085",
      :uid_ems                 => "40c1c666-e919-11e0-9c6b-005056af0085",
      :name                    => "Cluster2",
      :ha_enabled              => nil, # TODO: Should be true
      :ha_admit_control        => nil,
      :ha_max_failures         => nil,
      :drs_enabled             => nil, # TODO: Should be true
      :drs_automation_level    => nil,
      :drs_migration_threshold => nil
    )

    expect(@cluster.all_resource_pools_with_default.size).to eq(1)
    @default_rp = @cluster.default_resource_pool
    expect(@default_rp).to have_attributes(
      :ems_ref               => nil,
      :ems_ref_obj           => nil,
      :uid_ems               => "40c1c666-e919-11e0-9c6b-005056af0085_respool",
      :name                  => "Default for Cluster Cluster2",
      :memory_reserve        => nil,
      :memory_reserve_expand => nil,
      :memory_limit          => nil,
      :memory_shares         => nil,
      :memory_shares_level   => nil,
      :cpu_reserve           => nil,
      :cpu_reserve_expand    => nil,
      :cpu_limit             => nil,
      :cpu_shares            => nil,
      :cpu_shares_level      => nil,

      :is_default            => true
    )
  end

  def assert_specific_storage
    @storage = Storage.find_by_name("HostNFS")
    expect(@storage).to have_attributes(
      :ems_ref                       => "/api/storagedomains/65ca9577-0d95-4909-8532-4c45201fbfe4",
      :ems_ref_obj                   => "/api/storagedomains/65ca9577-0d95-4909-8532-4c45201fbfe4",
      :name                          => "HostNFS",
      :store_type                    => "NFS",
      :total_space                   => 168577466368,
      :free_space                    => 69793218560,
      :uncommitted                   => -363998478336, # TODO: ?????
      :multiplehostaccess            => 1, # TODO: Should this be a boolean column?
      :location                      => "192.168.252.119:/srv/nfs",
      :directory_hierarchy_supported => nil,
      :thin_provisioning_supported   => nil,
      :raw_disk_mappings_supported   => nil
    )
  end

  def assert_specific_host
    @host = ManageIQ::Providers::Redhat::InfraManager::Host.find_by_name("rhelvirt.manageiq.com")
    expect(@host).to have_attributes(
      :ems_ref          => "/api/hosts/ca389dbc-2054-11e1-9241-005056af0085",
      :ems_ref_obj      => "/api/hosts/ca389dbc-2054-11e1-9241-005056af0085",
      :name             => "rhelvirt.manageiq.com",
      :hostname         => "192.168.252.119",
      :ipaddress        => "192.168.252.119",
      :uid_ems          => "ca389dbc-2054-11e1-9241-005056af0085",
      :vmm_vendor       => "redhat",
      :vmm_version      => nil,
      :vmm_product      => "rhel",
      :vmm_buildnumber  => nil,
      :power_state      => "unknown",
      :connection_state => "connected"
    )

    expect(@host.ems_cluster).to eq(@cluster)
    expect(@host.storages.size).to eq(2)
    expect(@host.storages).to      include(@storage)

    expect(@host.operating_system).to have_attributes(
      :name         => "192.168.252.119", # TODO: ?????
      :product_name => "rhel",
      :version      => nil,
      :build_number => nil,
      :product_type => "linux"
    )

    expect(@host.system_services.size).to eq(0)

    expect(@host.switches.size).to eq(2)
    switch = @host.switches.find_by_name("rhevm")
    expect(switch).to have_attributes(
      :uid_ems           => "00000000-0000-0000-0000-000000000009",
      :name              => "rhevm",
      :ports             => nil,
      :allow_promiscuous => nil,
      :forged_transmits  => nil,
      :mac_changes       => nil
    )

    expect(switch.lans.size).to eq(1)
    @lan = switch.lans.find_by_name("rhevm")
    expect(@lan).to have_attributes(
      :uid_ems                    => "00000000-0000-0000-0000-000000000009",
      :name                       => "rhevm",
      :tag                        => nil,
      :allow_promiscuous          => nil,
      :forged_transmits           => nil,
      :mac_changes                => nil,
      :computed_allow_promiscuous => nil,
      :computed_forged_transmits  => nil,
      :computed_mac_changes       => nil
    )

    expect(@host.hardware).to have_attributes(
      :cpu_speed            => 2394,
      :cpu_type             => "Intel(R) Core(TM)2 Quad CPU    Q6600  @ 2.40GHz",
      :manufacturer         => "",
      :model                => "",
      :number_of_nics       => nil,
      :memory_mb            => 7806,
      :memory_console       => nil,
      :cpu_sockets          => 1,
      :cpu_total_cores      => 4,
      :cpu_cores_per_socket => 4,
      :guest_os             => nil,
      :guest_os_full_name   => nil,
      :vmotion_enabled      => nil,
      :cpu_usage            => nil,
      :memory_usage         => nil
    )

    expect(@host.hardware.networks.size).to eq(2)
    network = @host.hardware.networks.find_by_description("eth0")
    expect(network).to have_attributes(
      :description  => "eth0",
      :dhcp_enabled => nil,
      :ipaddress    => "192.168.252.119",
      :subnet_mask  => "255.255.254.0"
    )

    # TODO: Verify this host should have 2 nics, 2 cdroms, 1 floppy, any storage adapters?
    expect(@host.hardware.guest_devices.size).to eq(2)

    expect(@host.hardware.nics.size).to eq(2)
    nic = @host.hardware.nics.find_by_device_name("eth0")
    expect(nic).to have_attributes(
      :uid_ems         => "dc7bc21d-f0e6-4b1d-a627-adb82dfe9777",
      :device_name     => "eth0",
      :device_type     => "ethernet",
      :location        => "0",
      :present         => true,
      :controller_type => "ethernet"
    )
    expect(nic.switch).to eq(switch)
    expect(nic.network).to eq(network)

    expect(@host.hardware.storage_adapters.size).to eq(0) # TODO: See @host.hardware.guest_devices TODO
  end

  def assert_specific_vm_powered_on
    v = ManageIQ::Providers::Redhat::InfraManager::Vm.find_by_name("EmsRefreshSpec-PoweredOn")
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "/api/vms/fe052832-2350-48ce-8e56-c24b4cd91876",
      :ems_ref_obj           => "/api/vms/fe052832-2350-48ce-8e56-c24b4cd91876",
      :uid_ems               => "fe052832-2350-48ce-8e56-c24b4cd91876",
      :vendor                => "redhat",
      :raw_power_state       => "down",
      :power_state           => "off",
      :location              => "fe052832-2350-48ce-8e56-c24b4cd91876.ovf",
      :tools_status          => nil,
      :boot_time             => nil,
      :standby_action        => nil,
      :connection_state      => "connected",
      :cpu_affinity          => nil,
      :memory_reserve        => 682,
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
    expect(v.ems_cluster).to eq(@cluster)
    expect(v.parent_resource_pool).to eq(@default_rp)
    expect(v.host).to be_nil
    expect(v.storages).to eq([@storage])
    # v.storage  # TODO: Fix bug where duplication location GUIDs could cause the wrong value to appear.

    expect(v.operating_system).to have_attributes(
      :product_name => "rhel_6x64"
    )

    expect(v.custom_attributes.size).to eq(0)

    expect(v.snapshots.size).to eq(2)
    snapshot = v.snapshots.detect { |s| s.current == 1 } # TODO: Fix this boolean column
    expect(snapshot).to have_attributes(
      :uid         => "b5557722-d376-4201-b869-538204f67c01",
      :parent_uid  => "cf999f1f-aa72-4a0b-8fac-b208ce1de882",
      :uid_ems     => "b5557722-d376-4201-b869-538204f67c01",
      :name        => "Active Image",
      :description => "_ActiveImage_EmsRefreshSpec-PoweredOn_Wed Sep 26 14:46:28 EDT 2012",
      :current     => 1,
      :total_size  => nil,
      :filename    => nil
    )
    snapshot = snapshot.parent
    expect(snapshot).to have_attributes(
      :uid         => "cf999f1f-aa72-4a0b-8fac-b208ce1de882",
      :parent_uid  => nil,
      :uid_ems     => "cf999f1f-aa72-4a0b-8fac-b208ce1de882",
      :name        => "Active Image",
      :description => "_ActiveImage_EmsRefreshSpec-PoweredOn_Wed Sep 26 14:49:58 EDT 2012",
      :current     => 0
    )
    expect(snapshot.parent).to be_nil

    expect(v.hardware).to have_attributes(
      :guest_os           => "rhel_6x64",
      :guest_os_full_name => nil,
      :bios               => nil,
      :cpu_sockets        => 2,
      :annotation         => "Powered On VM for EmsRefresh testing",
      :memory_mb          => 1024
    )

    expect(v.hardware.disks.size).to eq(2)
    disk = v.hardware.disks.find_by_device_name("Disk 1")
    expect(disk).to have_attributes(
      :device_name     => "Disk 1",
      :device_type     => "disk",
      :controller_type => "virtio",
      :present         => true,
      :filename        => "061baae8-69bc-410c-a950-7d78be535c8c",
      :location        => "0",
      :size            => 5.gigabytes,
      :size_on_disk    => 0,
      :mode            => "persistent",
      :disk_type       => "thin",
      :start_connected => true
    )
    expect(disk.storage).to eq(@storage)

    expect(v.hardware.guest_devices.size).to eq(3)
    expect(v.hardware.nics.size).to eq(3)
    nic = v.hardware.nics.find_by_device_name("nic1")
    expect(nic).to have_attributes(
      :uid_ems         => "82a2b96c-b17d-4d22-9445-31da58f8b24a",
      :device_name     => "nic1",
      :device_type     => "ethernet",
      :controller_type => "ethernet",
      :present         => true,
      :start_connected => true,
      :address         => "00:1a:4a:a8:fc:12"
    )
    # nic.lan.should == @lan # TODO: Hook up this connection

    expect(v.hardware.networks.size).to eq(0)
    network = v.hardware.networks.first
    expect(network).to be_nil
    # nic.network.should == network # TODO: Hook up this connection

    expect(v.parent_datacenter).to have_attributes(
      :ems_ref     => "/api/datacenters/eb5592d2-ce76-11e0-a703-005056af0085",
      :ems_ref_obj => "/api/datacenters/eb5592d2-ce76-11e0-a703-005056af0085",
      :uid_ems     => "eb5592d2-ce76-11e0-a703-005056af0085",
      :name        => "Default",
      :type        => "Datacenter",

      :folder_path => "Datacenters/Default"
    )

    expect(v.parent_folder).to have_attributes(
      :ems_ref     => nil,
      :ems_ref_obj => nil,
      :uid_ems     => "root_dc",
      :name        => "Datacenters",
      :type        => nil,

      :folder_path => "Datacenters"
    )

    expect(v.parent_blue_folder).to have_attributes(
      :ems_ref     => nil,
      :ems_ref_obj => nil,
      :uid_ems     => "eb5592d2-ce76-11e0-a703-005056af0085_vm",
      :name        => "vm",
      :type        => nil,

      :folder_path => "Datacenters/Default/vm"
    )
  end

  def assert_specific_vm_powered_off
    v = ManageIQ::Providers::Redhat::InfraManager::Vm.find_by_name("EmsRefreshSpec-PoweredOff")
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "/api/vms/26a050fb-62c3-4645-9088-be6efec860e1",
      :ems_ref_obj           => "/api/vms/26a050fb-62c3-4645-9088-be6efec860e1",
      :uid_ems               => "26a050fb-62c3-4645-9088-be6efec860e1",
      :vendor                => "redhat",
      :raw_power_state       => "down",
      :power_state           => "off",
      :location              => "26a050fb-62c3-4645-9088-be6efec860e1.ovf",
      :tools_status          => nil,
      :boot_time             => nil,
      :standby_action        => nil,
      :connection_state      => "connected",
      :cpu_affinity          => nil,
      :memory_reserve        => 512,
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
    expect(v.ems_cluster).to eq(@cluster)
    expect(v.parent_resource_pool).to eq(@default_rp)
    expect(v.host).to be_nil
    expect(v.storages).to eq([@storage])
    # v.storage  # TODO: Fix bug where duplication location GUIDs could cause the wrong value to appear.

    expect(v.operating_system).to have_attributes(
      :product_name => "rhel_6x64"
    )

    expect(v.custom_attributes.size).to eq(0)

    expect(v.snapshots.size).to eq(4)
    snapshot = v.snapshots.detect { |s| s.current == 1 } # TODO: Fix this boolean column
    expect(snapshot).to have_attributes(
      :uid         => "4ecc2f4c-2932-4eea-8597-e6aad5da305a",
      :parent_uid  => "abf6f7aa-cd46-426e-83be-9f7a492a073b",
      :uid_ems     => "4ecc2f4c-2932-4eea-8597-e6aad5da305a",
      :name        => "Active Image",
      :description => "_ActiveImage_EmsRefreshSpec-PoweredOff_Wed Sep 26 14:37:54 EDT 2012",
      :current     => 1,
      :total_size  => nil,
      :filename    => nil
    )
    snapshot = snapshot.parent
    expect(snapshot).to have_attributes(
      :uid         => "abf6f7aa-cd46-426e-83be-9f7a492a073b",
      :parent_uid  => "123c6a56-7998-4275-bb8d-0f232f5d19a5",
      :uid_ems     => "abf6f7aa-cd46-426e-83be-9f7a492a073b",
      :name        => "Snapshot2",
      :description => "Snapshot2",
      :current     => 0
    )
    snapshot = snapshot.parent
    expect(snapshot).to have_attributes(
      :uid         => "123c6a56-7998-4275-bb8d-0f232f5d19a5",
      :parent_uid  => "1eaef769-fea8-4177-9f94-b78ef8f7a992",
      :uid_ems     => "123c6a56-7998-4275-bb8d-0f232f5d19a5",
      :name        => "Snapshot1",
      :description => "Snapshot1",
      :current     => 0
    )
    snapshot = snapshot.parent # TODO: This doesn't seem right. Also check powered on and template.
    expect(snapshot).to have_attributes(
      :uid         => "1eaef769-fea8-4177-9f94-b78ef8f7a992",
      :parent_uid  => nil,
      :uid_ems     => "1eaef769-fea8-4177-9f94-b78ef8f7a992",
      :name        => "Snapshot1",
      :description => "Snapshot1",
      :current     => 0
    )
    expect(snapshot.parent).to be_nil

    expect(v.hardware).to have_attributes(
      :guest_os           => "rhel_6x64",
      :guest_os_full_name => nil,
      :bios               => nil,
      :cpu_sockets        => 2,
      :annotation         => "Powered Off VM for EmsRefresh testing",
      :memory_mb          => 1024
    )

    expect(v.hardware.disks.size).to eq(2)
    disk = v.hardware.disks.find_by_device_name("Disk 1")
    expect(disk).to have_attributes(
      :device_name     => "Disk 1",
      :device_type     => "disk",
      :controller_type => "virtio",
      :present         => true,
      :filename        => "190fa724-91e7-49ba-8dcc-5dda4d0186d8",
      :location        => "0",
      :size            => 1.gigabytes,
      :mode            => "persistent",
      :disk_type       => "thin",
      :start_connected => true
    )
    expect(disk.storage).to eq(@storage)

    expect(v.hardware.guest_devices.size).to eq(3)
    expect(v.hardware.nics.size).to eq(3)
    nic = v.hardware.nics.find_by_device_name("nic1")
    expect(nic).to have_attributes(
      :uid_ems         => "c586cd90-fc74-4b17-9fad-f5a559b40bf2",
      :device_name     => "nic1",
      :device_type     => "ethernet",
      :controller_type => "ethernet",
      :present         => true,
      :start_connected => true,
      :address         => "00:1a:4a:a8:fc:0c"
    )
    expect(nic.lan).to     be_nil
    expect(nic.network).to be_nil

    expect(v.hardware.networks.size).to eq(0)

    expect(v.parent_datacenter).to have_attributes(
      :ems_ref     => "/api/datacenters/eb5592d2-ce76-11e0-a703-005056af0085",
      :ems_ref_obj => "/api/datacenters/eb5592d2-ce76-11e0-a703-005056af0085",
      :uid_ems     => "eb5592d2-ce76-11e0-a703-005056af0085",
      :name        => "Default",
      :type        => "Datacenter",

      :folder_path => "Datacenters/Default"
    )

    expect(v.parent_folder).to have_attributes(
      :ems_ref     => nil,
      :ems_ref_obj => nil,
      :uid_ems     => "root_dc",
      :name        => "Datacenters",
      :type        => nil,

      :folder_path => "Datacenters"
    )

    expect(v.parent_blue_folder).to have_attributes(
      :ems_ref     => nil,
      :ems_ref_obj => nil,
      :uid_ems     => "eb5592d2-ce76-11e0-a703-005056af0085_vm",
      :name        => "vm",
      :type        => nil,

      :folder_path => "Datacenters/Default/vm"
    )
  end

  def assert_specific_template
    v = ManageIQ::Providers::Redhat::InfraManager::Template.find_by_name("EmsRefreshSpec")
    expect(v).to have_attributes(
      :template              => true,
      :ems_ref               => "/api/templates/7a6db798-9df9-40ca-8cc3-3baab32e7613",
      :ems_ref_obj           => "/api/templates/7a6db798-9df9-40ca-8cc3-3baab32e7613",
      :uid_ems               => "7a6db798-9df9-40ca-8cc3-3baab32e7613",
      :vendor                => "redhat",
      :power_state           => "never",
      :location              => "7a6db798-9df9-40ca-8cc3-3baab32e7613.ovf",
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

    expect(v.ext_management_system).to eq(@ems)
    expect(v.ems_cluster).to eq(@cluster)
    expect(v.parent_resource_pool).to  be_nil
    expect(v.host).to                  be_nil
    expect(v.storages).to eq([@storage])
    # v.storage  # TODO: Fix bug where duplication location GUIDs could cause the wrong value to appear.

    expect(v.operating_system).to have_attributes(
      :product_name => "rhel_6x64"
    )

    expect(v.custom_attributes.size).to eq(0)
    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to have_attributes(
      :guest_os             => "rhel_6x64",
      :guest_os_full_name   => nil,
      :bios                 => nil,
      :cpu_sockets          => 2,
      :cpu_cores_per_socket => 1,
      :cpu_total_cores      => 2,
      :annotation           => "Template for EmsRefresh testing",
      :memory_mb            => 1024
    )

    expect(v.hardware.disks.size).to eq(2)
    disk = v.hardware.disks.find_by_device_name("Disk 1")
    expect(disk).to have_attributes(
      :device_name     => "Disk 1",
      :device_type     => "disk",
      :controller_type => "virtio",
      :present         => true,
      :filename        => "6b7e9778-e92a-4e08-b4f4-3887e81a226b",
      :location        => "0",
      :size            => 1.gigabytes,
      :mode            => "persistent",
      :disk_type       => "thin",
      :start_connected => true
    )
    expect(disk.storage).to eq(@storage)

    expect(v.hardware.guest_devices.size).to eq(0) # TODO: Should this be 3 like the other tests?
    expect(v.hardware.nics.size).to eq(0)
    expect(v.hardware.networks.size).to eq(0)

    expect(v.parent_datacenter).to have_attributes(
      :ems_ref     => "/api/datacenters/eb5592d2-ce76-11e0-a703-005056af0085",
      :ems_ref_obj => "/api/datacenters/eb5592d2-ce76-11e0-a703-005056af0085",
      :uid_ems     => "eb5592d2-ce76-11e0-a703-005056af0085",
      :name        => "Default",
      :type        => "Datacenter",

      :folder_path => "Datacenters/Default"
    )

    expect(v.parent_folder).to have_attributes(
      :ems_ref     => nil,
      :ems_ref_obj => nil,
      :uid_ems     => "root_dc",
      :name        => "Datacenters",
      :type        => nil,

      :folder_path => "Datacenters"
    )

    expect(v.parent_blue_folder).to have_attributes(
      :ems_ref     => nil,
      :ems_ref_obj => nil,
      :uid_ems     => "eb5592d2-ce76-11e0-a703-005056af0085_vm",
      :name        => "vm",
      :type        => nil,

      :folder_path => "Datacenters/Default/vm"
    )
  end

  def assert_relationship_tree
    expect(@ems.descendants_arranged).to match_relationship_tree(
      [EmsFolder, "Datacenters", {:hidden => true}] => {
        [Datacenter, "DC-iSCSI"] => {
          [EmsFolder, "host", {:hidden => true}] => {
            [EmsCluster, "Cluster1-iSCSI"] => {
              [ResourcePool, "Default for Cluster Cluster1-iSCSI"] => {
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "Brandon-Clone1"]   => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "CLI-Provision-1"]  => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-RH-5005-test"] => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-v5005"]        => {}
              }
            }
          },
          [EmsFolder, "vm", {:hidden => true}]   => {
            [ManageIQ::Providers::Redhat::InfraManager::Template, "Template1"]  => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "Brandon-Clone1"]   => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "CLI-Provision-1"]  => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-RH-5005-test"] => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-v5005"]        => {}
          }
        },
        [Datacenter, "DC2"]      => {
          [EmsFolder, "host", {:hidden => true}] => {
            [EmsCluster, "DC2-iSCSI"]   => {
              [ResourcePool, "Default for Cluster DC2-iSCSI"] => {}
            },
            [EmsCluster, "DC2Cluster1"] => {
              [ResourcePool, "Default for Cluster DC2Cluster1"] => {
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-TrunkSVN"] => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-V5001"]    => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "new-server"]   => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "RHEL"]         => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "ULin1"]        => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "V5-test"]      => {}
              }
            }
          },
          [EmsFolder, "vm", {:hidden => true}]   => {
            [ManageIQ::Providers::Redhat::InfraManager::Template, "EVM"]         => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "EVM-V5"]      => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "EVM-v5-Base"] => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "GM-Template"] => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-TrunkSVN"]      => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-V5001"]         => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "new-server"]        => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "RHEL"]              => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "ULin1"]             => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "V5-test"]           => {}
          }
        },
        [Datacenter, "Default"]  => {
          [EmsFolder, "host", {:hidden => true}] => {
            [EmsCluster, "Cluster2"] => {
              [ResourcePool, "Default for Cluster Cluster2"] => {
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "EmsRefreshSpec-PoweredOff"] => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "EmsRefreshSpec-PoweredOn"]  => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-RH-50013"]              => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-RH-50015"]              => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-V50025"]                => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "GM-Ubuntu-1"]               => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "kmwin2k8a"]                 => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "MIQ-PXE"]                   => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "obarenboim_test_01"]        => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "rpo-evm"]                   => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "rpo-test"]                  => {},
              }
            },
            [EmsCluster, "Default"]  => {
              [ResourcePool, "Default for Cluster Default"] => {}
            }
          },
          [EmsFolder, "vm", {:hidden => true}]   => {
            [ManageIQ::Providers::Redhat::InfraManager::Template, "empty"]               => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "EmsRefreshSpec"]      => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "EVM-50011"]           => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "EVM-v50017"]          => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "EVM-v50025"]          => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "EVMv5"]               => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "EVMv50015"]           => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "pxe-template"]        => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "pxe-template-wi"]     => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "EmsRefreshSpec-PoweredOff"] => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "EmsRefreshSpec-PoweredOn"]  => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-RH-50013"]              => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-RH-50015"]              => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-V50025"]                => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "GM-Ubuntu-1"]               => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "kmwin2k8a"]                 => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "MIQ-PXE"]                   => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "obarenboim_test_01"]        => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "rpo-evm"]                   => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "rpo-test"]                  => {},
          }
        }
      }
    )
  end
end
