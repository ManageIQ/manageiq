describe ManageIQ::Providers::Redhat::InfraManager::Refresh::Refresher do
  let(:ip_address) { '192.168.252.230' }

  before(:each) do
    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_redhat, :zone => zone, :hostname => ip_address, :ipaddress => ip_address, :port => 443)
    @ems.update_authentication(:default => {:userid => "evm@manageiq.com", :password => "password"})
    allow(@ems).to receive(:supported_api_versions).and_return([3])
    allow(@ems).to receive(:resolve_ip_address).with(ip_address).and_return(ip_address)
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:rhevm)
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
    expect(ExtManagementSystem.count).to eq(1)
    expect(EmsFolder.count).to eq(7)
    expect(EmsCluster.count).to eq(4)
    expect(Host.count).to eq(2)
    expect(ResourcePool.count).to eq(4)
    expect(VmOrTemplate.count).to eq(38)
    expect(Vm.count).to eq(27)
    expect(MiqTemplate.count).to eq(11)
    expect(Storage.count).to eq(8)

    expect(CustomAttribute.count).to eq(0) # TODO: 3.0 spec has values for this
    expect(CustomizationSpec.count).to eq(0)
    expect(Disk.count).to eq(66)
    expect(GuestDevice.count).to eq(30)
    expect(Hardware.count).to eq(40)
    expect(Lan.count).to eq(4)
    expect(MiqScsiLun.count).to eq(0)
    expect(MiqScsiTarget.count).to eq(0)
    expect(Network.count).to eq(6)
    expect(OperatingSystem.count).to eq(40)
    expect(Snapshot.count).to eq(32)
    expect(Switch.count).to eq(4)
    expect(SystemService.count).to eq(0)

    expect(Relationship.count).to eq(81)
    expect(MiqQueue.count).to eq(41)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :api_version => "3.1.0.0",
      :uid_ems     => nil
    )

    expect(@ems.ems_folders.size).to eq(7)
    expect(@ems.ems_clusters.size).to eq(4)
    expect(@ems.resource_pools.size).to eq(4)
    expect(@ems.storages.size).to eq(7)
    expect(@ems.hosts.size).to eq(2)
    expect(@ems.vms_and_templates.size).to eq(38)
    expect(@ems.vms.size).to eq(27)
    expect(@ems.miq_templates.size).to eq(11)

    expect(@ems.customization_specs.size).to eq(0)
  end

  def assert_specific_cluster
    @cluster = EmsCluster.find_by(:name => "iSCSI")
    expect(@cluster).to have_attributes(
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

    expect(@cluster.all_resource_pools_with_default.size).to eq(1)
    @default_rp = @cluster.default_resource_pool
    expect(@default_rp).to have_attributes(
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
    @storage = Storage.find_by(:name => "NetApp01Lun2")
    expect(@storage).to have_attributes(
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

    @storage2 = Storage.find_by(:name => "RHEVM31-1")
    expect(@storage2).to have_attributes(
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

    @storage3 = Storage.find_by(:name => "RHEVM31-gluster")
    expect(@storage3).to have_attributes(
      :ems_ref                       => "/api/storagedomains/efbe372b-7634-49f0-901e-0c05d526181f",
      :ems_ref_obj                   => "/api/storagedomains/efbe372b-7634-49f0-901e-0c05d526181f",
      :name                          => "RHEVM31-gluster",
      :store_type                    => "GLUSTERFS",
      :total_space                   => 20_401_094_656,
      :free_space                    => 16_106_127_360,
      :uncommitted                   => 19_327_352_832,
      :multiplehostaccess            => 1, # TODO: Should this be a boolean column?
      :location                      => "example.gluster.server.com:/gv0",
      :directory_hierarchy_supported => nil,
      :thin_provisioning_supported   => nil,
      :raw_disk_mappings_supported   => nil
    )
  end

  def assert_specific_host
    @host = ManageIQ::Providers::Redhat::InfraManager::Host.find_by(:name => "per410-rh1")
    expect(@host).to have_attributes(
      :ems_ref          => "/api/hosts/2f1d11cc-e269-11e2-839c-005056a217db",
      :ems_ref_obj      => "/api/hosts/2f1d11cc-e269-11e2-839c-005056a217db",
      :name             => "per410-rh1",
      :hostname         => "192.168.252.232",
      :ipaddress        => "192.168.252.232",
      :uid_ems          => "2f1d11cc-e269-11e2-839c-005056a217db",
      :vmm_vendor       => "redhat",
      :vmm_version      => nil,
      :vmm_product      => "rhel",
      :vmm_buildnumber  => nil,
      :power_state      => "on",
      :connection_state => "connected"
    )

    expect(@host.ems_cluster).to eq(@cluster)
    expect(@host.storages.size).to eq(4)
    expect(@host.storages).to      include(@storage)

    expect(@host.operating_system).to have_attributes(
      :name         => "192.168.252.232", # TODO: ?????
      :product_name => "rhel",
      :version      => nil,
      :build_number => nil,
      :product_type => "linux"
    )

    expect(@host.system_services.size).to eq(0)

    expect(@host.switches.size).to eq(3)
    switch = @host.switches.find_by(:name => "rhevm")
    expect(switch).to have_attributes(
      :uid_ems           => "00000000-0000-0000-0000-000000000009",
      :name              => "rhevm",
      :ports             => nil,
      :allow_promiscuous => nil,
      :forged_transmits  => nil,
      :mac_changes       => nil
    )

    expect(switch.lans.size).to eq(1)
    @lan = switch.lans.find_by(:name => "rhevm")
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
      :cpu_speed            => 1995,
      :cpu_type             => "Intel(R) Xeon(R) CPU           E5504  @ 2.00GHz",
      :manufacturer         => "",
      :model                => "",
      :number_of_nics       => 3,
      :memory_mb            => 56333,
      :memory_console       => nil,
      :cpu_sockets          => 2,
      :cpu_total_cores      => 8,
      :cpu_cores_per_socket => 4,
      :guest_os             => nil,
      :guest_os_full_name   => nil,
      :vmotion_enabled      => nil,
      :cpu_usage            => nil,
      :memory_usage         => nil
    )

    expect(@host.hardware.networks.size).to eq(3)
    network = @host.hardware.networks.find_by(:description => "em1")
    expect(network).to have_attributes(
      :description  => "em1",
      :dhcp_enabled => nil,
      :ipaddress    => "192.168.252.232",
      :subnet_mask  => "255.255.254.0"
    )

    nic_without_ip = @host.hardware.networks.find_by(:description => "em3")
    expect(nic_without_ip).to have_attributes(
      :description  => "em3",
      :dhcp_enabled => nil,
      :ipaddress    => nil,
      :subnet_mask  => nil
    )

    # TODO: Verify this host should have 3 nics, 2 cdroms, 1 floppy, any storage adapters?
    expect(@host.hardware.guest_devices.size).to eq(3)

    expect(@host.hardware.nics.size).to eq(3)
    nic = @host.hardware.nics.find_by_device_name("em1")
    expect(nic).to have_attributes(
      :uid_ems         => "1e783be8-fe80-456e-9a19-42329b03f28c",
      :device_name     => "em1",
      :device_type     => "ethernet",
      :location        => "1",
      :present         => true,
      :controller_type => "ethernet"
    )
    expect(nic.switch).to eq(switch)
    expect(nic.network).to eq(network)

    expect(@host.hardware.storage_adapters.size).to eq(0) # TODO: See @host.hardware.guest_devices TODO
  end

  def assert_specific_vm_powered_on
    v = ManageIQ::Providers::Redhat::InfraManager::Vm.find_by(:name => "EmsRefreshSpec-PoweredOn")
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "/api/vms/fe052832-2350-48ce-8e56-c24b4cd91876",
      :ems_ref_obj           => "/api/vms/fe052832-2350-48ce-8e56-c24b4cd91876",
      :uid_ems               => "fe052832-2350-48ce-8e56-c24b4cd91876",
      :vendor                => "redhat",
      :raw_power_state       => "up",
      :power_state           => "on",
      :location              => "fe052832-2350-48ce-8e56-c24b4cd91876.ovf",
      :tools_status          => nil,
      :boot_time             => Time.parse("2014-10-07T21:01:24.183000Z"),
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
    expect(v.host).to eq(@host)
    expect(v.storages).to eq([@storage])
    # v.storage  # TODO: Fix bug where duplication location GUIDs could cause the wrong value to appear.

    expect(v.operating_system).to have_attributes(
      :product_name => "rhel_6x64"
    )

    expect(v.custom_attributes.size).to eq(0)

    expect(v.snapshots.size).to eq(1)
    snapshot = v.snapshots.detect { |s| s.current == 1 } # TODO: Fix this boolean column
    expect(snapshot).to have_attributes(
      :uid         => "d7db04c1-9030-4c39-8618-3978787c3278",
      :parent_uid  => nil,
      :uid_ems     => "d7db04c1-9030-4c39-8618-3978787c3278",
      :name        => "Active VM",
      :description => "Active VM",
      :current     => 1,
      :total_size  => nil,
      :filename    => nil
    )
    expect(snapshot.parent).to be_nil

    expect(v.hardware).to have_attributes(
      :guest_os             => "rhel_6x64",
      :guest_os_full_name   => nil,
      :bios                 => nil,
      :cpu_cores_per_socket => 1,
      :cpu_total_cores      => 2,
      :cpu_sockets          => 2,
      :annotation           => "Powered On VM for EmsRefresh testing with DirectLUN Disk",
      :memory_mb            => 1024
    )

    expect(v.hardware.disks.size).to eq(3)
    disk = v.hardware.disks.find_by_device_name("EmsRefreshSpec-PoweredOn_Disk1")
    expect(disk).to have_attributes(
      :device_name     => "EmsRefreshSpec-PoweredOn_Disk1",
      :device_type     => "disk",
      :controller_type => "ide",
      :present         => true,
      :filename        => "5fc5484d-1730-42bc-adc3-262592ea595a",
      :location        => "0",
      :size            => 5.gigabytes,
      :size_on_disk    => 1.gigabytes,
      :mode            => "persistent",
      :disk_type       => "thin",
      :start_connected => true
    )
    expect(disk.storage).to eq(@storage)

    # DirectLUN disk
    disk = v.hardware.disks.find_by_device_name("EmsRefreshSpec-PoweredOn_Disk3")
    expect(disk).to have_attributes(
      :device_name     => "EmsRefreshSpec-PoweredOn_Disk3",
      :device_type     => "disk",
      :controller_type => "virtio",
      :present         => true,
      :filename        => "b7139a48-854b-49b4-b4a0-92ef88261b7b",
      :location        => "1",
      :size            => 1.gigabytes,
      :size_on_disk    => 1.gigabytes,
      :mode            => "persistent",
      :disk_type       => "thick",
      :start_connected => true
    )
    expect(disk.storage).to eq(@storage)

    expect(v.hardware.guest_devices.size).to eq(3)
    expect(v.hardware.nics.size).to eq(3)
    nic = v.hardware.nics.find_by_device_name("nic1")
    expect(nic).to have_attributes(
      :uid_ems         => "98610918-86f6-45a9-b96f-b9849ab3ad7d",
      :device_name     => "nic1",
      :device_type     => "ethernet",
      :controller_type => "ethernet",
      :present         => true,
      :start_connected => true,
      :address         => "00:1a:4a:a8:fc:12"
    )
    # nic.lan.should == @lan # TODO: Hook up this connection

    expect(v.hardware.networks.size).to eq(1)
    network = v.hardware.networks.first
    expect(network).to have_attributes(
      :hostname    => "server.example.com",
      :ipaddress   => "192.168.253.45",
      :ipv6address => nil
    )
    # nic.network.should == network # TODO: Hook up this connection

    expect(v.parent_datacenter).to have_attributes(
      :ems_ref     => "/api/datacenters/45b5a710-eccd-11e1-bc2c-005056a217db",
      :ems_ref_obj => "/api/datacenters/45b5a710-eccd-11e1-bc2c-005056a217db",
      :uid_ems     => "45b5a710-eccd-11e1-bc2c-005056a217db",
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
      :uid_ems     => "45b5a710-eccd-11e1-bc2c-005056a217db_vm",
      :name        => "vm",
      :type        => nil,

      :folder_path => "Datacenters/Default/vm"
    )
  end

  def assert_specific_vm_powered_off
    v = ManageIQ::Providers::Redhat::InfraManager::Vm.find_by(:name => "EmsRefreshSpec-PoweredOff")
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
    expect(v.storages).to eq([@storage2])
    # v.storage  # TODO: Fix bug where duplication location GUIDs could cause the wrong value to appear.

    expect(v.operating_system).to have_attributes(
      :product_name => "rhel_6x64"
    )

    expect(v.custom_attributes.size).to eq(0)

    expect(v.snapshots.size).to eq(3)
    snapshot = v.snapshots.detect { |s| s.current == 1 } # TODO: Fix this boolean column
    expect(snapshot).to have_attributes(
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
    expect(snapshot).to have_attributes(
      :uid         => "edbc4501-23a6-45c9-a736-b378f45a2aec",
      :parent_uid  => "f5990c3f-c608-4fc7-b50d-17fe1d389757",
      :uid_ems     => "edbc4501-23a6-45c9-a736-b378f45a2aec",
      :name        => "Snapshot1",
      :description => "Snapshot1",
      :current     => 0
    )
    snapshot = snapshot.parent
    expect(snapshot).to have_attributes(
      :uid         => "f5990c3f-c608-4fc7-b50d-17fe1d389757",
      :parent_uid  => nil,
      :uid_ems     => "f5990c3f-c608-4fc7-b50d-17fe1d389757",
      :name        => "Snapshot2",
      :description => "Snapshot2",
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
      :filename        => "21fc55f7-2775-4fec-8442-fa546e06fabc",
      :location        => "0",
      :size            => 1.gigabytes,
      :mode            => "persistent",
      :disk_type       => "thin",
      :start_connected => true
    )
    expect(disk.storage).to eq(@storage2)

    expect(v.hardware.guest_devices.size).to eq(3)
    expect(v.hardware.nics.size).to eq(3)
    nic = v.hardware.nics.find_by_device_name("nic1")
    expect(nic).to have_attributes(
      :uid_ems         => "f2b9d3dc-e948-4ec9-a746-b03c409cfd18",
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
      :ems_ref     => "/api/datacenters/45b5a710-eccd-11e1-bc2c-005056a217db",
      :ems_ref_obj => "/api/datacenters/45b5a710-eccd-11e1-bc2c-005056a217db",
      :uid_ems     => "45b5a710-eccd-11e1-bc2c-005056a217db",
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
      :uid_ems     => "45b5a710-eccd-11e1-bc2c-005056a217db_vm",
      :name        => "vm",
      :type        => nil,

      :folder_path => "Datacenters/Default/vm"
    )
  end

  def assert_specific_template
    v = ManageIQ::Providers::Redhat::InfraManager::Template.find_by(:name => "EmsRefreshSpec-Template")
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
    expect(v.storages).to eq([@storage2])
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
    disk = v.hardware.disks.find_by_device_name("EmsRefreshSpec_Disk1")
    expect(disk).to have_attributes(
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
    expect(disk.storage).to eq(@storage2)

    expect(v.hardware.guest_devices.size).to eq(0) # TODO: Should this be 3 like the other tests?
    expect(v.hardware.nics.size).to eq(0)
    expect(v.hardware.networks.size).to eq(0)

    expect(v.parent_datacenter).to have_attributes(
      :ems_ref     => "/api/datacenters/45b5a710-eccd-11e1-bc2c-005056a217db",
      :ems_ref_obj => "/api/datacenters/45b5a710-eccd-11e1-bc2c-005056a217db",
      :uid_ems     => "45b5a710-eccd-11e1-bc2c-005056a217db",
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
      :uid_ems     => "45b5a710-eccd-11e1-bc2c-005056a217db_vm",
      :name        => "vm",
      :type        => nil,

      :folder_path => "Datacenters/Default/vm"
    )
  end

  def assert_relationship_tree
    expect(@ems.descendants_arranged).to match_relationship_tree(
      [EmsFolder, "Datacenters", {:hidden => true}] => {
        [Datacenter, "Default"] => {
          [EmsFolder, "host", {:hidden => true}] => {
            [EmsCluster, "iSCSI"] => {
              [ResourcePool, "Default for Cluster iSCSI"] => {
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "BD-F17-Desktop"]                => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-DHS-Test"]                  => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "EmsRefreshSpec-NoDisks-NoNics"] => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "EmsRefreshSpec-PoweredOff"]     => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "EmsRefreshSpec-PoweredOn"]      => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "abc123"]                        => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "abc1234"]                       => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "bd-isotest-14-ir"]              => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "bd-isotest-14-pr"]              => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "bd-wintest"]                    => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "bd-wintest-01-18-c"]            => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "bill-t1"]                       => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "evm-5012"]                      => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "lucy-test"]                     => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "lucy_cpu"]                      => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "lucy_cpu7"]                     => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "lucy_cpu8"]                     => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "miqutil"]                       => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "rmtest06"]                      => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "rpo-evm-iscsi"]                 => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "rpo-test1"]                     => {},
              }
            }
          },
          [EmsFolder, "vm", {:hidden => true}]   => {
            [ManageIQ::Providers::Redhat::InfraManager::Template, "CFME_Base"]               => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "EVM-v50017"]              => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "EVM-v50025"]              => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "EmsRefreshSpec-Template"] => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "PxeRhelRhevm31"]          => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "evm-v5012"]               => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "rmrhel"]                  => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "BD-F17-Desktop"]                => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "EVM-DHS-Test"]                  => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "EmsRefreshSpec-NoDisks-NoNics"] => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "EmsRefreshSpec-PoweredOff"]     => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "EmsRefreshSpec-PoweredOn"]      => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "abc123"]                        => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "abc1234"]                       => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "bd-isotest-14-ir"]              => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "bd-isotest-14-pr"]              => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "bd-wintest"]                    => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "bd-wintest-01-18-c"]            => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "bill-t1"]                       => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "evm-5012"]                      => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "lucy-test"]                     => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "lucy_cpu"]                      => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "lucy_cpu7"]                     => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "lucy_cpu8"]                     => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "miqutil"]                       => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "rmtest06"]                      => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "rpo-evm-iscsi"]                 => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "rpo-test1"]                     => {},
          }
        },
        [Datacenter, "NFS"]     => {
          [EmsFolder, "host", {:hidden => true}] => {
            [EmsCluster, "NFS"] => {
              [ResourcePool, "Default for Cluster NFS"] => {
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "MK_AUG_05_003_DELETE"] => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "aab_demo_vm"]          => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "aab_test_vm"]          => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "bd-testiso1"]          => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "bd1"]                  => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "rpo-test2"]            => {},
              }
            }
          },
          [EmsFolder, "vm", {:hidden => true}]   => {
            [ManageIQ::Providers::Redhat::InfraManager::Template, "757e824d-6d97-4568-be29-9346c354e802"] => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "bd-clone-template"]                    => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "bd-temp1"]                             => {},
            [ManageIQ::Providers::Redhat::InfraManager::Template, "prov-template"]                        => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "MK_AUG_05_003_DELETE"]                       => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "aab_demo_vm"]                                => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "aab_test_vm"]                                => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "bd-testiso1"]                                => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "bd1"]                                        => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "rpo-test2"]                                  => {},
          },
        }
      }
    )
  end
end
