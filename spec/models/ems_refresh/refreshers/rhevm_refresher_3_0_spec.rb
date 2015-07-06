require "spec_helper"

describe EmsRefresh::Refreshers::RhevmRefresher do
  before(:each) do
    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_redhat, :zone => zone, :hostname => "192.168.252.231", :ipaddress => "192.168.252.231", :port => 8443)
    @ems.update_authentication(:default => {:userid => "evm@manageiq.com", :password => "password"})
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
    ExtManagementSystem.count.should == 1
    EmsFolder.count.should           == 10
    EmsCluster.count.should          == 5
    Host.count.should                == 1
    ResourcePool.count.should        == 5
    VmOrTemplate.count.should        == 35
    Vm.count.should                  == 21
    MiqTemplate.count.should         == 14
    Storage.count.should             == 6

    CustomAttribute.count.should     == 3
    CustomizationSpec.count.should   == 0
    Disk.count.should                == 124
    GuestDevice.count.should         == 26
    Hardware.count.should            == 36
    Lan.count.should                 == 2
    MiqScsiLun.count.should          == 0
    MiqScsiTarget.count.should       == 0
    Network.count.should             == 2
    OperatingSystem.count.should     == 36
    Snapshot.count.should            == 41
    Switch.count.should              == 2
    SystemService.count.should       == 0

    Relationship.count.should        == 77
    # MiqQueue.count.should            == 35 #PENDING: Some timing issue keeps flipping this between 35 and 36
  end

  def assert_ems
    @ems.should have_attributes(
      :api_version => "3.0.0.0",
      :uid_ems     => nil
    )

    @ems.ems_folders.size.should       == 10
    @ems.ems_clusters.size.should      == 5
    @ems.resource_pools.size.should    == 5
    @ems.storages.size.should          == 2 # TODO: The table count is 6, but this is 4 ??
    @ems.hosts.size.should             == 1
    @ems.vms_and_templates.size.should == 35
    @ems.vms.size.should               == 21
    @ems.miq_templates.size.should     == 14

    @ems.customization_specs.size.should == 0
  end

  def assert_specific_cluster
    @cluster = EmsCluster.find_by_name("Cluster2")
    @cluster.should have_attributes(
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

    @cluster.all_resource_pools_with_default.size.should == 1
    @default_rp = @cluster.default_resource_pool
    @default_rp.should have_attributes(
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
    @storage.should have_attributes(
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
    @host = HostRedhat.find_by_name("rhelvirt.manageiq.com")
    @host.should have_attributes(
      :ems_ref          => "/api/hosts/ca389dbc-2054-11e1-9241-005056af0085",
      :ems_ref_obj      => "/api/hosts/ca389dbc-2054-11e1-9241-005056af0085",
      :name             => "rhelvirt.manageiq.com",
      :hostname         => "192.168.252.119",
      :ipaddress        => "192.168.252.119",
      :uid_ems          => "ca389dbc-2054-11e1-9241-005056af0085",
      :vmm_vendor       => "RedHat",
      :vmm_version      => nil,
      :vmm_product      => "rhel",
      :vmm_buildnumber  => nil,
      :power_state      => "unknown",
      :connection_state => "connected"
    )

    @host.ems_cluster.should   == @cluster
    @host.storages.size.should == 2
    @host.storages.should      include(@storage)

    @host.operating_system.should have_attributes(
      :name         => "192.168.252.119", # TODO: ?????
      :product_name => "linux",
      :version      => nil,
      :build_number => nil,
      :product_type => nil
    )

    @host.system_services.size.should == 0

    @host.switches.size.should == 2
    switch = @host.switches.find_by_name("rhevm")
    switch.should have_attributes(
      :uid_ems           => "00000000-0000-0000-0000-000000000009",
      :name              => "rhevm",
      :ports             => nil,
      :allow_promiscuous => nil,
      :forged_transmits  => nil,
      :mac_changes       => nil
    )

    switch.lans.size.should == 1
    @lan = switch.lans.find_by_name("rhevm")
    @lan.should have_attributes(
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

    @host.hardware.should have_attributes(
      :cpu_speed          => 2394,
      :cpu_type           => "Intel(R) Core(TM)2 Quad CPU    Q6600  @ 2.40GHz",
      :manufacturer       => "",
      :model              => "",
      :number_of_nics     => nil,
      :memory_cpu         => 7806,
      :memory_console     => nil,
      :numvcpus           => 1,
      :logical_cpus       => 4,
      :cores_per_socket   => 4,
      :guest_os           => nil,
      :guest_os_full_name => nil,
      :vmotion_enabled    => nil,
      :cpu_usage          => nil,
      :memory_usage       => nil
    )

    @host.hardware.networks.size.should == 2
    network = @host.hardware.networks.find_by_description("eth0")
    network.should have_attributes(
      :description  => "eth0",
      :dhcp_enabled => nil,
      :ipaddress    => "192.168.252.119",
      :subnet_mask  => "255.255.254.0"
    )

    @host.hardware.guest_devices.size.should == 2 # TODO: Verify this host should have 2 nics, 2 cdroms, 1 floppy, any storage adapters?

    @host.hardware.nics.size.should == 2
    nic = @host.hardware.nics.find_by_device_name("eth0")
    nic.should have_attributes(
      :uid_ems         => "dc7bc21d-f0e6-4b1d-a627-adb82dfe9777",
      :device_name     => "eth0",
      :device_type     => "ethernet",
      :location        => "0",
      :present         => true,
      :controller_type => "ethernet"
    )
    nic.switch.should  == switch
    nic.network.should == network

    @host.hardware.storage_adapters.size.should == 0 # TODO: See @host.hardware.guest_devices TODO
  end

  def assert_specific_vm_powered_on
    v = VmRedhat.find_by_name("EmsRefreshSpec-PoweredOn")
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "/api/vms/fe052832-2350-48ce-8e56-c24b4cd91876",
      :ems_ref_obj           => "/api/vms/fe052832-2350-48ce-8e56-c24b4cd91876",
      :uid_ems               => "fe052832-2350-48ce-8e56-c24b4cd91876",
      :vendor                => "RedHat",
      :raw_power_state       => "down",
      :power_state           => "off",
      :location              => "fe052832-2350-48ce-8e56-c24b4cd91876.ovf",
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

    v.ext_management_system.should == @ems
    v.ems_cluster.should           == @cluster
    v.parent_resource_pool.should  == @default_rp
    v.host.should                  == nil
    v.storages.should              == [@storage]
    # v.storage  # TODO: Fix bug where duplication location GUIDs could cause the wrong value to appear.

    v.operating_system.should have_attributes(
      :product_name => "rhel_6x64"
    )

    v.custom_attributes.size.should == 0

    v.snapshots.size.should == 2
    snapshot = v.snapshots.detect { |s| s.current == 1 } # TODO: Fix this boolean column
    snapshot.should have_attributes(
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
    snapshot.should have_attributes(
      :uid         => "cf999f1f-aa72-4a0b-8fac-b208ce1de882",
      :parent_uid  => nil,
      :uid_ems     => "cf999f1f-aa72-4a0b-8fac-b208ce1de882",
      :name        => "Active Image",
      :description => "_ActiveImage_EmsRefreshSpec-PoweredOn_Wed Sep 26 14:49:58 EDT 2012",
      :current     => 0
    )
    snapshot.parent.should be_nil

    v.hardware.should have_attributes(
      :guest_os           => "rhel_6x64",
      :guest_os_full_name => nil,
      :bios               => nil,
      :numvcpus           => 2,
      :annotation         => "Powered On VM for EmsRefresh testing",
      :memory_cpu         => 1024 # TODO: Should this be in bytes?
    )

    v.hardware.disks.size.should == 2
    disk = v.hardware.disks.find_by_device_name("Disk 1")
    disk.should have_attributes(
      :device_name     => "Disk 1",
      :device_type     => "disk",
      :controller_type => "virtio",
      :present         => true,
      :filename        => "061baae8-69bc-410c-a950-7d78be535c8c",
      :location        => "0",
      :size            => 5.gigabytes,
      :mode            => "persistent",
      :disk_type       => "thin",
      :start_connected => true
    )
    disk.storage.should == @storage

    v.hardware.guest_devices.size.should == 3
    v.hardware.nics.size.should == 3
    nic = v.hardware.nics.find_by_device_name("nic1")
    nic.should have_attributes(
      :uid_ems         => "82a2b96c-b17d-4d22-9445-31da58f8b24a",
      :device_name     => "nic1",
      :device_type     => "ethernet",
      :controller_type => "ethernet",
      :present         => true,
      :start_connected => true,
      :address         => "00:1a:4a:a8:fc:12"
    )
    # nic.lan.should == @lan # TODO: Hook up this connection

    v.hardware.networks.size.should == 0
    network = v.hardware.networks.first
    network.should be_nil
    # nic.network.should == network # TODO: Hook up this connection

    v.parent_datacenter.should have_attributes(
      :ems_ref       => "/api/datacenters/eb5592d2-ce76-11e0-a703-005056af0085",
      :ems_ref_obj   => "/api/datacenters/eb5592d2-ce76-11e0-a703-005056af0085",
      :uid_ems       => "eb5592d2-ce76-11e0-a703-005056af0085",
      :name          => "Default",
      :is_datacenter => true,

      :folder_path   => "Datacenters/Default"
    )

    v.parent_folder.should have_attributes(
      :ems_ref       => nil,
      :ems_ref_obj   => nil,
      :uid_ems       => "root_dc",
      :name          => "Datacenters",
      :is_datacenter => false,

      :folder_path   => "Datacenters"
    )

    v.parent_blue_folder.should have_attributes(
      :ems_ref       => nil,
      :ems_ref_obj   => nil,
      :uid_ems       => "eb5592d2-ce76-11e0-a703-005056af0085_vm",
      :name          => "vm",
      :is_datacenter => false,

      :folder_path   => "Datacenters/Default/vm"
    )
  end

  def assert_specific_vm_powered_off
    v = VmRedhat.find_by_name("EmsRefreshSpec-PoweredOff")
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "/api/vms/26a050fb-62c3-4645-9088-be6efec860e1",
      :ems_ref_obj           => "/api/vms/26a050fb-62c3-4645-9088-be6efec860e1",
      :uid_ems               => "26a050fb-62c3-4645-9088-be6efec860e1",
      :vendor                => "RedHat",
      :raw_power_state       => "down",
      :power_state           => "off",
      :location              => "26a050fb-62c3-4645-9088-be6efec860e1.ovf",
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

    v.ext_management_system.should == @ems
    v.ems_cluster.should           == @cluster
    v.parent_resource_pool.should  == @default_rp
    v.host.should                  be_nil
    v.storages.should              == [@storage]
    # v.storage  # TODO: Fix bug where duplication location GUIDs could cause the wrong value to appear.

    v.operating_system.should have_attributes(
      :product_name => "rhel_6x64"
    )

    v.custom_attributes.size.should == 0

    v.snapshots.size.should == 4
    snapshot = v.snapshots.detect { |s| s.current == 1 } # TODO: Fix this boolean column
    snapshot.should have_attributes(
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
    snapshot.should have_attributes(
      :uid         => "abf6f7aa-cd46-426e-83be-9f7a492a073b",
      :parent_uid  => "123c6a56-7998-4275-bb8d-0f232f5d19a5",
      :uid_ems     => "abf6f7aa-cd46-426e-83be-9f7a492a073b",
      :name        => "Snapshot2",
      :description => "Snapshot2",
      :current     => 0
    )
    snapshot = snapshot.parent
    snapshot.should have_attributes(
      :uid         => "123c6a56-7998-4275-bb8d-0f232f5d19a5",
      :parent_uid  => "1eaef769-fea8-4177-9f94-b78ef8f7a992",
      :uid_ems     => "123c6a56-7998-4275-bb8d-0f232f5d19a5",
      :name        => "Snapshot1",
      :description => "Snapshot1",
      :current     => 0
    )
    snapshot = snapshot.parent # TODO: This doesn't seem right. Also check powered on and template.
    snapshot.should have_attributes(
      :uid         => "1eaef769-fea8-4177-9f94-b78ef8f7a992",
      :parent_uid  => nil,
      :uid_ems     => "1eaef769-fea8-4177-9f94-b78ef8f7a992",
      :name        => "Snapshot1",
      :description => "Snapshot1",
      :current     => 0
    )
    snapshot.parent.should be_nil

    v.hardware.should have_attributes(
      :guest_os           => "rhel_6x64",
      :guest_os_full_name => nil,
      :bios               => nil,
      :numvcpus           => 2,
      :annotation         => "Powered Off VM for EmsRefresh testing",
      :memory_cpu         => 1024 # TODO: Should this be in bytes?
    )

    v.hardware.disks.size.should == 2
    disk = v.hardware.disks.find_by_device_name("Disk 1")
    disk.should have_attributes(
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
    disk.storage.should == @storage

    v.hardware.guest_devices.size.should == 3
    v.hardware.nics.size.should == 3
    nic = v.hardware.nics.find_by_device_name("nic1")
    nic.should have_attributes(
      :uid_ems         => "c586cd90-fc74-4b17-9fad-f5a559b40bf2",
      :device_name     => "nic1",
      :device_type     => "ethernet",
      :controller_type => "ethernet",
      :present         => true,
      :start_connected => true,
      :address         => "00:1a:4a:a8:fc:0c"
    )
    nic.lan.should     be_nil
    nic.network.should be_nil

    v.hardware.networks.size.should == 0

    v.parent_datacenter.should have_attributes(
      :ems_ref       => "/api/datacenters/eb5592d2-ce76-11e0-a703-005056af0085",
      :ems_ref_obj   => "/api/datacenters/eb5592d2-ce76-11e0-a703-005056af0085",
      :uid_ems       => "eb5592d2-ce76-11e0-a703-005056af0085",
      :name          => "Default",
      :is_datacenter => true,

      :folder_path   => "Datacenters/Default"
    )

    v.parent_folder.should have_attributes(
      :ems_ref       => nil,
      :ems_ref_obj   => nil,
      :uid_ems       => "root_dc",
      :name          => "Datacenters",
      :is_datacenter => false,

      :folder_path   => "Datacenters"
    )

    v.parent_blue_folder.should have_attributes(
      :ems_ref       => nil,
      :ems_ref_obj   => nil,
      :uid_ems       => "eb5592d2-ce76-11e0-a703-005056af0085_vm",
      :name          => "vm",
      :is_datacenter => false,

      :folder_path   => "Datacenters/Default/vm"
    )
  end

  def assert_specific_template
    v = TemplateRedhat.find_by_name("EmsRefreshSpec")
    v.should have_attributes(
      :template              => true,
      :ems_ref               => "/api/templates/7a6db798-9df9-40ca-8cc3-3baab32e7613",
      :ems_ref_obj           => "/api/templates/7a6db798-9df9-40ca-8cc3-3baab32e7613",
      :uid_ems               => "7a6db798-9df9-40ca-8cc3-3baab32e7613",
      :vendor                => "RedHat",
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

    v.ext_management_system.should == @ems
    v.ems_cluster.should           == @cluster
    v.parent_resource_pool.should  be_nil
    v.host.should                  be_nil
    v.storages.should              == [@storage]
    # v.storage  # TODO: Fix bug where duplication location GUIDs could cause the wrong value to appear.

    v.operating_system.should have_attributes(
      :product_name => "rhel_6x64"
    )

    v.custom_attributes.size.should == 0
    v.snapshots.size.should == 0

    v.hardware.should have_attributes(
      :guest_os           => "rhel_6x64",
      :guest_os_full_name => nil,
      :bios               => nil,
      :numvcpus           => 2,
      :cores_per_socket   => 1,
      :logical_cpus       => 2,
      :annotation         => "Template for EmsRefresh testing",
      :memory_cpu         => 1024 # TODO: Should this be in bytes?
    )

    v.hardware.disks.size.should == 2
    disk = v.hardware.disks.find_by_device_name("Disk 1")
    disk.should have_attributes(
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
    disk.storage.should == @storage

    v.hardware.guest_devices.size.should == 0 # TODO: Should this be 3 like the other tests?
    v.hardware.nics.size.should == 0
    v.hardware.networks.size.should == 0

    v.parent_datacenter.should have_attributes(
      :ems_ref       => "/api/datacenters/eb5592d2-ce76-11e0-a703-005056af0085",
      :ems_ref_obj   => "/api/datacenters/eb5592d2-ce76-11e0-a703-005056af0085",
      :uid_ems       => "eb5592d2-ce76-11e0-a703-005056af0085",
      :name          => "Default",
      :is_datacenter => true,

      :folder_path   => "Datacenters/Default"
    )

    v.parent_folder.should have_attributes(
      :ems_ref       => nil,
      :ems_ref_obj   => nil,
      :uid_ems       => "root_dc",
      :name          => "Datacenters",
      :is_datacenter => false,

      :folder_path   => "Datacenters"
    )

    v.parent_blue_folder.should have_attributes(
      :ems_ref       => nil,
      :ems_ref_obj   => nil,
      :uid_ems       => "eb5592d2-ce76-11e0-a703-005056af0085_vm",
      :name          => "vm",
      :is_datacenter => false,

      :folder_path   => "Datacenters/Default/vm"
    )
  end

  def assert_relationship_tree
    @ems.descendants_arranged.should match_relationship_tree(
      [EmsFolder, "Datacenters", {:is_datacenter => false}] => {
        [EmsFolder, "DC-iSCSI", {:is_datacenter => true}] => {
          [EmsFolder, "host", {:is_datacenter => false}] => {
            [EmsCluster, "Cluster1-iSCSI"] => {
              [ResourcePool, "Default for Cluster Cluster1-iSCSI", {:is_default => true}] => {
                [VmRedhat, "Brandon-Clone1"] => {},
                [VmRedhat, "CLI-Provision-1"] => {},
                [VmRedhat, "EVM-RH-5005-test"] => {},
                [VmRedhat, "EVM-v5005"] => {}
              }
            }
          },
          [EmsFolder, "vm", {:is_datacenter => false}] => {
            [TemplateRedhat, "Template1"] => {},
            [VmRedhat, "Brandon-Clone1"] => {},
            [VmRedhat, "CLI-Provision-1"] => {},
            [VmRedhat, "EVM-RH-5005-test"] => {},
            [VmRedhat, "EVM-v5005"] => {}
          }
        },
        [EmsFolder, "DC2", {:is_datacenter => true}] => {
          [EmsFolder, "host", {:is_datacenter => false}] => {
            [EmsCluster, "DC2-iSCSI"] => {
              [ResourcePool, "Default for Cluster DC2-iSCSI", {:is_default => true}] => {}
            },
            [EmsCluster, "DC2Cluster1"] => {
              [ResourcePool, "Default for Cluster DC2Cluster1", {:is_default => true}] => {
                [VmRedhat, "EVM-TrunkSVN"] => {},
                [VmRedhat, "EVM-V5001"] => {},
                [VmRedhat, "new-server"] => {},
                [VmRedhat, "RHEL"] => {},
                [VmRedhat, "ULin1"] => {},
                [VmRedhat, "V5-test"] => {}
              }
            }
          },
          [EmsFolder, "vm", {:is_datacenter => false}] => {
            [TemplateRedhat, "EVM"] => {},
            [TemplateRedhat, "EVM-V5"] => {},
            [TemplateRedhat, "EVM-v5-Base"] => {},
            [TemplateRedhat, "GM-Template"] => {},
            [VmRedhat, "EVM-TrunkSVN"] => {},
            [VmRedhat, "EVM-V5001"] => {},
            [VmRedhat, "new-server"] => {},
            [VmRedhat, "RHEL"] => {},
            [VmRedhat, "ULin1"] => {},
            [VmRedhat, "V5-test"] => {}
          }
        },
        [EmsFolder, "Default", {:is_datacenter => true}] => {
          [EmsFolder, "host", {:is_datacenter => false}] => {
            [EmsCluster, "Cluster2"] => {
              [ResourcePool, "Default for Cluster Cluster2", {:is_default => true}] => {
                [VmRedhat, "EmsRefreshSpec-PoweredOff"] => {},
                [VmRedhat, "EmsRefreshSpec-PoweredOn"] => {},
                [VmRedhat, "EVM-RH-50013"] => {},
                [VmRedhat, "EVM-RH-50015"] => {},
                [VmRedhat, "EVM-V50025"] => {},
                [VmRedhat, "GM-Ubuntu-1"] => {},
                [VmRedhat, "kmwin2k8a"] => {},
                [VmRedhat, "MIQ-PXE"] => {},
                [VmRedhat, "obarenboim_test_01"] => {},
                [VmRedhat, "rpo-evm"] => {},
                [VmRedhat, "rpo-test"] => {},
              }
            },
            [EmsCluster, "Default"] => {
              [ResourcePool, "Default for Cluster Default", {:is_default => true}] => {}
            }
          },
          [EmsFolder, "vm", {:is_datacenter => false}] => {
            [TemplateRedhat, "empty"] => {},
            [TemplateRedhat, "EmsRefreshSpec"] => {},
            [TemplateRedhat, "EVM-50011"] => {},
            [TemplateRedhat, "EVM-v50017"] => {},
            [TemplateRedhat, "EVM-v50025"] => {},
            [TemplateRedhat, "EVMv5"] => {},
            [TemplateRedhat, "EVMv50015"] => {},
            [TemplateRedhat, "pxe-template"] => {},
            [TemplateRedhat, "pxe-template-wi"] => {},
            [VmRedhat, "EmsRefreshSpec-PoweredOff"] => {},
            [VmRedhat, "EmsRefreshSpec-PoweredOn"] => {},
            [VmRedhat, "EVM-RH-50013"] => {},
            [VmRedhat, "EVM-RH-50015"] => {},
            [VmRedhat, "EVM-V50025"] => {},
            [VmRedhat, "GM-Ubuntu-1"] => {},
            [VmRedhat, "kmwin2k8a"] => {},
            [VmRedhat, "MIQ-PXE"] => {},
            [VmRedhat, "obarenboim_test_01"] => {},
            [VmRedhat, "rpo-evm"] => {},
            [VmRedhat, "rpo-test"] => {},
          }
        }
      }
    )
  end
end
