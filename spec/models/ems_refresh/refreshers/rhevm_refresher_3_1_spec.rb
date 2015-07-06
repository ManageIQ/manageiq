require "spec_helper"

describe EmsRefresh::Refreshers::RhevmRefresher do
  before(:each) do
    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_redhat, :zone => zone, :hostname => "192.168.252.230", :ipaddress => "192.168.252.230", :port => 443)
    @ems.update_authentication(:default => {:userid => "evm@manageiq.com", :password => "password"})
  end

  it "will perform a full refresh on v3.1" do
    VCR.use_cassette("#{described_class.name.underscore}_3_1") do
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
    EmsFolder.count.should           == 7
    EmsCluster.count.should          == 4
    Host.count.should                == 2
    ResourcePool.count.should        == 4
    VmOrTemplate.count.should        == 38
    Vm.count.should                  == 27
    MiqTemplate.count.should         == 11
    Storage.count.should             == 7

    CustomAttribute.count.should     == 0 # TODO: 3.0 spec has values for this
    CustomizationSpec.count.should   == 0
    Disk.count.should                == 66
    GuestDevice.count.should         == 29
    Hardware.count.should            == 40
    Lan.count.should                 == 3
    MiqScsiLun.count.should          == 0
    MiqScsiTarget.count.should       == 0
    Network.count.should             == 5
    OperatingSystem.count.should     == 40
    Snapshot.count.should            == 32
    Switch.count.should              == 3
    SystemService.count.should       == 0

    Relationship.count.should        == 81
    MiqQueue.count.should            == 41
  end

  def assert_ems
    @ems.should have_attributes(
      :api_version => "3.1.0.0",
      :uid_ems     => nil
    )

    @ems.ems_folders.size.should       == 7
    @ems.ems_clusters.size.should      == 4
    @ems.resource_pools.size.should    == 4
    @ems.storages.size.should          == 7
    @ems.hosts.size.should             == 2
    @ems.vms_and_templates.size.should == 38
    @ems.vms.size.should               == 27
    @ems.miq_templates.size.should     == 11

    @ems.customization_specs.size.should == 0
  end

  def assert_specific_cluster
    @cluster = EmsCluster.find_by_name("iSCSI")
    @cluster.should have_attributes(
      :ems_ref                 => "/api/clusters/99408929-82cf-4dc7-a532-9d998063fa95",
      :ems_ref_obj             => "/api/clusters/99408929-82cf-4dc7-a532-9d998063fa95",
      :uid_ems                 => "99408929-82cf-4dc7-a532-9d998063fa95",
      :name                    => "iSCSI",
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
      :uid_ems               => "99408929-82cf-4dc7-a532-9d998063fa95_respool",
      :name                  => "Default for Cluster iSCSI",
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
    @storage = Storage.find_by_name("NetApp01Lun2")
    @storage.should have_attributes(
      :ems_ref                       => "/api/storagedomains/6284e934-9f11-486a-b9d8-aaacfa4f226f",
      :ems_ref_obj                   => "/api/storagedomains/6284e934-9f11-486a-b9d8-aaacfa4f226f",
      :name                          => "NetApp01Lun2",
      :store_type                    => "ISCSI",
      :total_space                   => 106300440576,
      :free_space                    => 57982058496,
      :uncommitted                   => 36507222016,
      :multiplehostaccess            => 1, # TODO: Should this be a boolean column?
      :location                      => "360a980005034442f525a716549583947",
      :directory_hierarchy_supported => nil,
      :thin_provisioning_supported   => nil,
      :raw_disk_mappings_supported   => nil
    )

    @storage2 = Storage.find_by_name("RHEVM31-1")
    @storage2.should have_attributes(
      :ems_ref                       => "/api/storagedomains/d0a7d751-46bc-495a-a312-e5d010059f96",
      :ems_ref_obj                   => "/api/storagedomains/d0a7d751-46bc-495a-a312-e5d010059f96",
      :name                          => "RHEVM31-1",
      :store_type                    => "ISCSI",
      :total_space                   => 273804165120,
      :free_space                    => 137438953472,
      :uncommitted                   => 45097156608,
      :multiplehostaccess            => 1, # TODO: Should this be a boolean column?
      :location                      => nil,
      :directory_hierarchy_supported => nil,
      :thin_provisioning_supported   => nil,
      :raw_disk_mappings_supported   => nil
    )
  end

  def assert_specific_host
    @host = HostRedhat.find_by_name("per410-rh1")
    @host.should have_attributes(
      :ems_ref          => "/api/hosts/2f1d11cc-e269-11e2-839c-005056a217db",
      :ems_ref_obj      => "/api/hosts/2f1d11cc-e269-11e2-839c-005056a217db",
      :name             => "per410-rh1",
      :hostname         => "192.168.252.232",
      :ipaddress        => "192.168.252.232",
      :uid_ems          => "2f1d11cc-e269-11e2-839c-005056a217db",
      :vmm_vendor       => "RedHat",
      :vmm_version      => nil,
      :vmm_product      => "rhel",
      :vmm_buildnumber  => nil,
      :power_state      => "on",
      :connection_state => "connected"
    )

    @host.ems_cluster.should   == @cluster
    @host.storages.size.should == 4
    @host.storages.should      include(@storage)

    @host.operating_system.should have_attributes(
      :name         => "192.168.252.232", # TODO: ?????
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
      :cpu_speed          => 1995,
      :cpu_type           => "Intel(R) Xeon(R) CPU           E5504  @ 2.00GHz",
      :manufacturer       => "",
      :model              => "",
      :number_of_nics     => nil,
      :memory_cpu         => 56333,
      :memory_console     => nil,
      :numvcpus           => 2,
      :logical_cpus       => 8,
      :cores_per_socket   => 4,
      :guest_os           => nil,
      :guest_os_full_name => nil,
      :vmotion_enabled    => nil,
      :cpu_usage          => nil,
      :memory_usage       => nil
    )

    @host.hardware.networks.size.should == 2
    network = @host.hardware.networks.find_by_description("em1")
    network.should have_attributes(
      :description  => "em1",
      :dhcp_enabled => nil,
      :ipaddress    => "192.168.252.232",
      :subnet_mask  => "255.255.254.0"
    )

    @host.hardware.guest_devices.size.should == 2 # TODO: Verify this host should have 2 nics, 2 cdroms, 1 floppy, any storage adapters?

    @host.hardware.nics.size.should == 2
    nic = @host.hardware.nics.find_by_device_name("em1")
    nic.should have_attributes(
      :uid_ems         => "1e783be8-fe80-456e-9a19-42329b03f28c",
      :device_name     => "em1",
      :device_type     => "ethernet",
      :location        => "1",
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
      :raw_power_state       => "up",
      :power_state           => "on",
      :location              => "fe052832-2350-48ce-8e56-c24b4cd91876.ovf",
      :tools_status          => nil,
      :boot_time             => Time.parse("2014-10-07T21:01:24.183000Z"),
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
    v.host.should                  == @host
    v.storages.should              == [@storage]
    # v.storage  # TODO: Fix bug where duplication location GUIDs could cause the wrong value to appear.

    v.operating_system.should have_attributes(
      :product_name => "rhel_6x64"
    )

    v.custom_attributes.size.should == 0

    v.snapshots.size.should == 1
    snapshot = v.snapshots.detect { |s| s.current == 1 } # TODO: Fix this boolean column
    snapshot.should have_attributes(
      :uid         => "d7db04c1-9030-4c39-8618-3978787c3278",
      :parent_uid  => nil,
      :uid_ems     => "d7db04c1-9030-4c39-8618-3978787c3278",
      :name        => "Active VM",
      :description => "Active VM",
      :current     => 1,
      :total_size  => nil,
      :filename    => nil
    )
    snapshot.parent.should be_nil

    v.hardware.should have_attributes(
      :guest_os           => "rhel_6x64",
      :guest_os_full_name => nil,
      :bios               => nil,
      :cores_per_socket   => 1,
      :logical_cpus       => 2,
      :numvcpus           => 2,
      :annotation         => "Powered On VM for EmsRefresh testing with DirectLUN Disk",
      :memory_cpu         => 1024 # TODO: Should this be in bytes?
    )

    v.hardware.disks.size.should == 3
    disk = v.hardware.disks.find_by_device_name("EmsRefreshSpec-PoweredOn_Disk1")
    disk.should have_attributes(
      :device_name     => "EmsRefreshSpec-PoweredOn_Disk1",
      :device_type     => "disk",
      :controller_type => "ide",
      :present         => true,
      :filename        => "5fc5484d-1730-42bc-adc3-262592ea595a",
      :location        => "0",
      :size            => 5.gigabytes,
      :mode            => "persistent",
      :disk_type       => "thin",
      :start_connected => true
    )
    disk.storage.should == @storage

    # DirectLUN disk
    disk = v.hardware.disks.find_by_device_name("EmsRefreshSpec-PoweredOn_Disk3")
    disk.should have_attributes(
      :device_name     => "EmsRefreshSpec-PoweredOn_Disk3",
      :device_type     => "disk",
      :controller_type => "virtio",
      :present         => true,
      :filename        => "b7139a48-854b-49b4-b4a0-92ef88261b7b",
      :location        => "1",
      :size            => 1.gigabytes,
      :mode            => "persistent",
      :disk_type       => "thick",
      :start_connected => true
    )
    disk.storage.should == @storage

    v.hardware.guest_devices.size.should == 3
    v.hardware.nics.size.should == 3
    nic = v.hardware.nics.find_by_device_name("nic1")
    nic.should have_attributes(
      :uid_ems         => "98610918-86f6-45a9-b96f-b9849ab3ad7d",
      :device_name     => "nic1",
      :device_type     => "ethernet",
      :controller_type => "ethernet",
      :present         => true,
      :start_connected => true,
      :address         => "00:1a:4a:a8:fc:12"
    )
    # nic.lan.should == @lan # TODO: Hook up this connection

    v.hardware.networks.size.should == 1
    network = v.hardware.networks.first
    network.should have_attributes(
      :hostname    => nil, # TODO: Should be miq-winxpsp3 (or something like that)?
      :ipaddress   => "192.168.253.45",
      :ipv6address => nil
    )
    # nic.network.should == network # TODO: Hook up this connection

    v.parent_datacenter.should have_attributes(
      :ems_ref       => "/api/datacenters/45b5a710-eccd-11e1-bc2c-005056a217db",
      :ems_ref_obj   => "/api/datacenters/45b5a710-eccd-11e1-bc2c-005056a217db",
      :uid_ems       => "45b5a710-eccd-11e1-bc2c-005056a217db",
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
      :uid_ems       => "45b5a710-eccd-11e1-bc2c-005056a217db_vm",
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
    v.storages.should              == [@storage2]
    # v.storage  # TODO: Fix bug where duplication location GUIDs could cause the wrong value to appear.

    v.operating_system.should have_attributes(
      :product_name => "rhel_6x64"
    )

    v.custom_attributes.size.should == 0

    v.snapshots.size.should == 3
    snapshot = v.snapshots.detect { |s| s.current == 1 } # TODO: Fix this boolean column
    snapshot.should have_attributes(
      :uid         => "a49102de-1e2a-45b7-b464-185f959dbfbb",
      :parent_uid  => "edbc4501-23a6-45c9-a736-b378f45a2aec",
      :uid_ems     => "a49102de-1e2a-45b7-b464-185f959dbfbb",
      :name        => "Active VM",
      :description => "Active VM",
      :current     => 1,
      :total_size  => nil,
      :filename    => nil
    )
    snapshot = snapshot.parent # TODO: THIS IS COMPLETELY WRONG
    snapshot.should have_attributes(
      :uid         => "edbc4501-23a6-45c9-a736-b378f45a2aec",
      :parent_uid  => "f5990c3f-c608-4fc7-b50d-17fe1d389757",
      :uid_ems     => "edbc4501-23a6-45c9-a736-b378f45a2aec",
      :name        => "Snapshot1",
      :description => "Snapshot1",
      :current     => 0
    )
    snapshot = snapshot.parent
    snapshot.should have_attributes(
      :uid         => "f5990c3f-c608-4fc7-b50d-17fe1d389757",
      :parent_uid  => nil,
      :uid_ems     => "f5990c3f-c608-4fc7-b50d-17fe1d389757",
      :name        => "Snapshot2",
      :description => "Snapshot2",
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
      :filename        => "21fc55f7-2775-4fec-8442-fa546e06fabc",
      :location        => "0",
      :size            => 1.gigabytes,
      :mode            => "persistent",
      :disk_type       => "thin",
      :start_connected => true
    )
    disk.storage.should == @storage2

    v.hardware.guest_devices.size.should == 3
    v.hardware.nics.size.should == 3
    nic = v.hardware.nics.find_by_device_name("nic1")
    nic.should have_attributes(
      :uid_ems         => "f2b9d3dc-e948-4ec9-a746-b03c409cfd18",
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
      :ems_ref       => "/api/datacenters/45b5a710-eccd-11e1-bc2c-005056a217db",
      :ems_ref_obj   => "/api/datacenters/45b5a710-eccd-11e1-bc2c-005056a217db",
      :uid_ems       => "45b5a710-eccd-11e1-bc2c-005056a217db",
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
      :uid_ems       => "45b5a710-eccd-11e1-bc2c-005056a217db_vm",
      :name          => "vm",
      :is_datacenter => false,

      :folder_path   => "Datacenters/Default/vm"
    )
  end

  def assert_specific_template
    v = TemplateRedhat.find_by_name("EmsRefreshSpec-Template")
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
    v.storages.should              == [@storage2]
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
    disk = v.hardware.disks.find_by_device_name("EmsRefreshSpec_Disk1")
    disk.should have_attributes(
      :device_name     => "EmsRefreshSpec_Disk1",
      :device_type     => "disk",
      :controller_type => "virtio",
      :present         => true,
      :filename        => "95a35764-4e49-4d6c-895f-33948f30ea69",
      :location        => "0",
      :size            => 1.gigabytes,
      :mode            => "persistent",
      :disk_type       => "thin",
      :start_connected => true
    )
    disk.storage.should == @storage2

    v.hardware.guest_devices.size.should == 0 # TODO: Should this be 3 like the other tests?
    v.hardware.nics.size.should == 0
    v.hardware.networks.size.should == 0

    v.parent_datacenter.should have_attributes(
      :ems_ref       => "/api/datacenters/45b5a710-eccd-11e1-bc2c-005056a217db",
      :ems_ref_obj   => "/api/datacenters/45b5a710-eccd-11e1-bc2c-005056a217db",
      :uid_ems       => "45b5a710-eccd-11e1-bc2c-005056a217db",
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
      :uid_ems       => "45b5a710-eccd-11e1-bc2c-005056a217db_vm",
      :name          => "vm",
      :is_datacenter => false,

      :folder_path   => "Datacenters/Default/vm"
    )
  end

  def assert_relationship_tree
    @ems.descendants_arranged.should match_relationship_tree(
      [EmsFolder, "Datacenters"] => {
        [EmsFolder, "Default"] => {
          [EmsFolder, "host"] => {
            [EmsCluster, "iSCSI"] => {
              [ResourcePool, "Default for Cluster iSCSI"] => {
                [VmRedhat, "BD-F17-Desktop"] => {},
                [VmRedhat, "EVM-DHS-Test"] => {},
                [VmRedhat, "EmsRefreshSpec-NoDisks-NoNics"] => {},
                [VmRedhat, "EmsRefreshSpec-PoweredOff"] => {},
                [VmRedhat, "EmsRefreshSpec-PoweredOn"] => {},
                [VmRedhat, "abc123"] => {},
                [VmRedhat, "abc1234"] => {},
                [VmRedhat, "bd-isotest-14-ir"] => {},
                [VmRedhat, "bd-isotest-14-pr"] => {},
                [VmRedhat, "bd-wintest"] => {},
                [VmRedhat, "bd-wintest-01-18-c"] => {},
                [VmRedhat, "bill-t1"] => {},
                [VmRedhat, "evm-5012"] => {},
                [VmRedhat, "lucy-test"] => {},
                [VmRedhat, "lucy_cpu"] => {},
                [VmRedhat, "lucy_cpu7"] => {},
                [VmRedhat, "lucy_cpu8"] => {},
                [VmRedhat, "miqutil"] => {},
                [VmRedhat, "rmtest06"] => {},
                [VmRedhat, "rpo-evm-iscsi"] => {},
                [VmRedhat, "rpo-test1"] => {},
              }
            }
          },
          [EmsFolder, "vm"] => {
            [TemplateRedhat, "CFME_Base"] => {},
            [TemplateRedhat, "EVM-v50017"] => {},
            [TemplateRedhat, "EVM-v50025"] => {},
            [TemplateRedhat, "EmsRefreshSpec-Template"] => {},
            [TemplateRedhat, "PxeRhelRhevm31"] => {},
            [TemplateRedhat, "evm-v5012"] => {},
            [TemplateRedhat, "rmrhel"] => {},
            [VmRedhat, "BD-F17-Desktop"] => {},
            [VmRedhat, "EVM-DHS-Test"] => {},
            [VmRedhat, "EmsRefreshSpec-NoDisks-NoNics"] => {},
            [VmRedhat, "EmsRefreshSpec-PoweredOff"] => {},
            [VmRedhat, "EmsRefreshSpec-PoweredOn"] => {},
            [VmRedhat, "abc123"] => {},
            [VmRedhat, "abc1234"] => {},
            [VmRedhat, "bd-isotest-14-ir"] => {},
            [VmRedhat, "bd-isotest-14-pr"] => {},
            [VmRedhat, "bd-wintest"] => {},
            [VmRedhat, "bd-wintest-01-18-c"] => {},
            [VmRedhat, "bill-t1"] => {},
            [VmRedhat, "evm-5012"] => {},
            [VmRedhat, "lucy-test"] => {},
            [VmRedhat, "lucy_cpu"] => {},
            [VmRedhat, "lucy_cpu7"] => {},
            [VmRedhat, "lucy_cpu8"] => {},
            [VmRedhat, "miqutil"] => {},
            [VmRedhat, "rmtest06"] => {},
            [VmRedhat, "rpo-evm-iscsi"] => {},
            [VmRedhat, "rpo-test1"] => {},
          }
        },
        [EmsFolder, "NFS"] => {
          [EmsFolder, "host"] => {
            [EmsCluster, "NFS"] => {
              [ResourcePool, "Default for Cluster NFS"] => {
                [VmRedhat, "MK_AUG_05_003_DELETE"] => {},
                [VmRedhat, "aab_demo_vm"] => {},
                [VmRedhat, "aab_test_vm"] => {},
                [VmRedhat, "bd-testiso1"] => {},
                [VmRedhat, "bd1"] => {},
                [VmRedhat, "rpo-test2"] => {},
              }
            }
          },
          [EmsFolder, "vm"] => {
            [TemplateRedhat, "757e824d-6d97-4568-be29-9346c354e802"] => {},
            [TemplateRedhat, "bd-clone-template"] => {},
            [TemplateRedhat, "bd-temp1"] => {},
            [TemplateRedhat, "prov-template"] => {},
            [VmRedhat, "MK_AUG_05_003_DELETE"] => {},
            [VmRedhat, "aab_demo_vm"] => {},
            [VmRedhat, "aab_test_vm"] => {},
            [VmRedhat, "bd-testiso1"] => {},
            [VmRedhat, "bd1"] => {},
            [VmRedhat, "rpo-test2"] => {},
          },
        }
      }
    )
  end
end
