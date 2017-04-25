describe ManageIQ::Providers::Redhat::InfraManager::Refresh::Refresher do
  before(:each) do
    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_redhat, :zone => zone, :hostname => "localhost", :ipaddress => "localhost",
                              :port => 8443)
    @ems.update_authentication(:default => {:userid => "admin@internal", :password => "123456"})
    allow(@ems).to receive(:supported_api_versions).and_return([3, 4])
    stub_settings_merge(:ems => { :ems_redhat => { :use_ovirt_engine_sdk => true } })
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:rhevm)
  end

  require 'yaml'
  def load_response_mock_for(filename)
    prefix = described_class.name.underscore
    YAML.load_file(File.join('spec', 'models', prefix, 'response_yamls', filename + '.yml'))
  end

  before(:each) do
    inventory_wrapper_class = ManageIQ::Providers::Redhat::InfraManager::Inventory::Strategies::V4
    allow_any_instance_of(inventory_wrapper_class)
      .to receive(:collect_clusters).and_return(load_response_mock_for('clusters'))
    allow_any_instance_of(inventory_wrapper_class)
      .to receive(:collect_storages).and_return(load_response_mock_for('storages'))
    allow_any_instance_of(inventory_wrapper_class)
      .to receive(:collect_hosts).and_return(load_response_mock_for('hosts'))
    allow_any_instance_of(inventory_wrapper_class)
      .to receive(:collect_vms).and_return(load_response_mock_for('vms'))
    allow_any_instance_of(inventory_wrapper_class)
      .to receive(:collect_templates).and_return(load_response_mock_for('templates'))
    allow_any_instance_of(inventory_wrapper_class)
      .to receive(:collect_networks).and_return(load_response_mock_for('networks'))
    allow_any_instance_of(inventory_wrapper_class)
      .to receive(:collect_datacenters).and_return(load_response_mock_for('datacenters'))
    allow_any_instance_of(inventory_wrapper_class).to receive(:api).and_return("4.2.0_master")
    allow_any_instance_of(inventory_wrapper_class).to receive(:service)
      .and_return(OpenStruct.new(:version_string => '4.2.0_master'))
  end

  it "will perform a full refresh on v4.1" do
    VCR.use_cassette("#{described_class.name.underscore}_4_1", :allow_unused_http_interactions => true, :allow_playback_repeats => true, :record => :new_episodes) do
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
    expect(EmsCluster.count).to eq(3)
    expect(Host.count).to eq(3)
    expect(ResourcePool.count).to eq(3)
    expect(VmOrTemplate.count).to eq(10)
    expect(Vm.count).to eq(8)
    expect(MiqTemplate.count).to eq(2)
    expect(Storage.count).to eq(5)

    expect(CustomAttribute.count).to eq(0) # TODO: 3.0 spec has values for this
    expect(CustomizationSpec.count).to eq(0)
    expect(Disk.count).to eq(5)
    expect(GuestDevice.count).to eq(7)
    expect(Hardware.count).to eq(13)
    expect(Lan.count).to eq(3)
    expect(MiqScsiLun.count).to eq(0)
    expect(MiqScsiTarget.count).to eq(0)
    expect(Network.count).to eq(7)
    expect(OperatingSystem.count).to eq(13)
    expect(Snapshot.count).to eq(11)
    expect(Switch.count).to eq(3)
    expect(SystemService.count).to eq(0)

    expect(Relationship.count).to eq(32)
    expect(MiqQueue.count).to eq(13)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :api_version => "4.2.0_master",
      :uid_ems     => nil
    )

    expect(@ems.ems_folders.size).to eq(7)
    expect(@ems.ems_clusters.size).to eq(3)
    expect(@ems.resource_pools.size).to eq(3)
    expect(@ems.storages.size).to eq(4)
    expect(@ems.hosts.size).to eq(3)
    expect(@ems.vms_and_templates.size).to eq(10)
    expect(@ems.vms.size).to eq(8)
    expect(@ems.miq_templates.size).to eq(2)

    expect(@ems.customization_specs.size).to eq(0)
  end

  def assert_specific_cluster
    @cluster = EmsCluster.find_by(:name => 'cc1')
    expect(@cluster).to have_attributes(
      :ems_ref                 => "/api/clusters/504ae500-3476-450e-8243-f6df0f7f7acf",
      :ems_ref_obj             => "/api/clusters/504ae500-3476-450e-8243-f6df0f7f7acf",
      :uid_ems                 => "504ae500-3476-450e-8243-f6df0f7f7acf",
      :name                    => "cc1",
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
      :uid_ems               => "504ae500-3476-450e-8243-f6df0f7f7acf_respool",
      :name                  => "Default for Cluster cc1",
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
    @storage = Storage.find_by(:name => "data1")
    expect(@storage).to have_attributes(
      :ems_ref                       => "/api/storagedomains/27a3bcce-c4d0-4bce-afe9-1d669d5a9d02",
      :ems_ref_obj                   => "/api/storagedomains/27a3bcce-c4d0-4bce-afe9-1d669d5a9d02",
      :name                          => "data1",
      :store_type                    => "NFS",
      :total_space                   => 53_687_091_200,
      :free_space                    => 46_170_898_432,
      :uncommitted                   => -17_179_869_184,
      :multiplehostaccess            => 1, # TODO: Should this be a boolean column?
      :location                      => "spider.eng.lab.tlv.redhat.com:/vol/vol_bodnopoz/data1",
      :directory_hierarchy_supported => nil,
      :thin_provisioning_supported   => nil,
      :raw_disk_mappings_supported   => nil
    )
    @storage2 = Storage.find_by(:name => "data2")
    expect(@storage2).to have_attributes(
      :ems_ref                       => "/api/storagedomains/4672fe17-c260-4ecc-aab0-b535f4d0dbeb",
      :ems_ref_obj                   => "/api/storagedomains/4672fe17-c260-4ecc-aab0-b535f4d0dbeb",
      :name                          => "data2",
      :store_type                    => "NFS",
      :total_space                   => 53_687_091_200,
      :free_space                    => 46_170_898_432,
      :uncommitted                   => 49392123904,
      :multiplehostaccess            => 1, # TODO: Should this be a boolean column?
      :location                      => "spider.eng.lab.tlv.redhat.com:/vol/vol_bodnopoz/data2",
      :directory_hierarchy_supported => nil,
      :thin_provisioning_supported   => nil,
      :raw_disk_mappings_supported   => nil
    )
  end

  def assert_specific_host
    @host = ManageIQ::Providers::Redhat::InfraManager::Host.find_by(:name => "bodh1")
    expect(@host).to have_attributes(
      :ems_ref          => "/api/hosts/5bf6b336-f86d-4551-ac08-d34621ec5f0a",
      :ems_ref_obj      => "/api/hosts/5bf6b336-f86d-4551-ac08-d34621ec5f0a",
      :name             => "bodh1",
      :hostname         => "bodh1.usersys.redhat.com",
      :ipaddress        => "10.35.19.12",
      :uid_ems          => "5bf6b336-f86d-4551-ac08-d34621ec5f0a",
      :vmm_vendor       => "redhat",
      :vmm_version      => "7",
      :vmm_product      => "rhel",
      :vmm_buildnumber  => nil,
      :power_state      => "on",
      :connection_state => "connected"
    )

    @host_cluster = EmsCluster.find_by(:ems_ref => "/api/clusters/00000002-0002-0002-0002-000000000092")

    expect(@host.ems_cluster).to eq(@host_cluster)
    expect(@host.storages.size).to eq(1)
    expect(@host.storages).to      include(@storage2)

    expect(@host.operating_system).to have_attributes(
      :name         => "bodh1.usersys.redhat.com", # TODO: ?????
      :product_name => "RHEL",
      :version      => "7 - 1.1503.el7.centos.2.8",
      :build_number => nil,
      :product_type => "linux"
    )

    expect(@host.system_services.size).to eq(0)

    expect(@host.switches.size).to eq(1)
    switch = @host.switches.first
    expect(switch).to have_attributes(
      :uid_ems           => "00000000-0000-0000-0000-000000000009",
      :name              => "ovirtmgmt",
      :ports             => nil,
      :allow_promiscuous => nil,
      :forged_transmits  => nil,
      :mac_changes       => nil
    )

    expect(switch.lans.size).to eq(1)
    @lan = switch.lans.first
    expect(@lan).to have_attributes(
      :uid_ems                    => "00000000-0000-0000-0000-000000000009",
      :name                       => "ovirtmgmt",
      :tag                        => nil,
      :allow_promiscuous          => nil,
      :forged_transmits           => nil,
      :mac_changes                => nil,
      :computed_allow_promiscuous => nil,
      :computed_forged_transmits  => nil,
      :computed_mac_changes       => nil
    )

    expect(@host.hardware).to have_attributes(
      :cpu_speed            => 2400,
      :cpu_type             => "Westmere E56xx/L56xx/X56xx (Nehalem-C)",
      :manufacturer         => "Red Hat",
      :model                => "RHEV Hypervisor",
      :number_of_nics       => nil,
      :memory_mb            => 3789,
      :memory_console       => nil,
      :cpu_sockets          => 2,
      :cpu_total_cores      => 2,
      :cpu_cores_per_socket => 1,
      :guest_os             => nil,
      :guest_os_full_name   => nil,
      :vmotion_enabled      => nil,
      :cpu_usage            => nil,
      :memory_usage         => nil
    )

    expect(@host.hardware.networks.size).to eq(1)
    network = @host.hardware.networks.find_by(:description => "eth0")
    expect(network).to have_attributes(
      :description  => "eth0",
      :dhcp_enabled => nil,
      :ipaddress    => "10.35.19.12",
      :subnet_mask  => "255.255.252.0"
    )

    # TODO: Verify this host should have 3 nics, 2 cdroms, 1 floppy, any storage adapters?
    expect(@host.hardware.guest_devices.size).to eq(1)

    expect(@host.hardware.nics.size).to eq(1)
    nic = @host.hardware.nics.first
    expect(nic).to have_attributes(
      :uid_ems         => "01c2d4a8-5d7a-4960-bfc4-ca1b400a9bdd",
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
    v = ManageIQ::Providers::Redhat::InfraManager::Vm.find_by(:name => "vm1")
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "/api/vms/3a9401a0-bf3d-4496-8acf-edd3e903511f",
      :ems_ref_obj           => "/api/vms/3a9401a0-bf3d-4496-8acf-edd3e903511f",
      :uid_ems               => "3a9401a0-bf3d-4496-8acf-edd3e903511f",
      :vendor                => "redhat",
      :raw_power_state       => "up",
      :power_state           => "on",
      :location              => "3a9401a0-bf3d-4496-8acf-edd3e903511f.ovf",
      :tools_status          => nil,
      :boot_time             => Time.zone.parse("2016-12-28T11:59:55.6020000Z"),
      :standby_action        => nil,
      :connection_state      => "connected",
      :cpu_affinity          => nil,
      :memory_reserve        => 2024,
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
    host = ManageIQ::Providers::Redhat::InfraManager::Host.find_by(:name => "bodh2")
    expect(v.host).to eq(host)
    expect(v.storages).to eq([@storage])
    # v.storage  # TODO: Fix bug where duplication location GUIDs could cause the wrong value to appear.

    expect(v.operating_system).to have_attributes(
      :product_name => "other"
    )

    expect(v.hostnames).to match_array(%w(vm-18-82.eng.lab.tlv.redhat.com))
    expect(v.custom_attributes.size).to eq(0)

    expect(v.snapshots.size).to eq(2)
    snapshot = v.snapshots.detect { |s| s.current == 1 } # TODO: Fix this boolean column
    expect(snapshot).to have_attributes(
      :uid         => "e13fc61c-c566-4264-9a75-0e62fe5d7a30",
      :parent_uid  => "05ff445a-0bfc-44c3-90d1-a338e9095510",
      :uid_ems     => "e13fc61c-c566-4264-9a75-0e62fe5d7a30",
      :name        => "Active VM",
      :description => "Active VM",
      :current     => 1,
      :total_size  => nil,
      :filename    => nil
    )
    snapshot_parent = ManageIQ::Providers::Redhat::InfraManager::Snapshot.find_by(:name => "vm1_snap")
    expect(snapshot.parent).to eq(snapshot_parent)

    expect(v.hardware).to have_attributes(
      :guest_os             => "other",
      :guest_os_full_name   => nil,
      :bios                 => nil,
      :cpu_cores_per_socket => 1,
      :cpu_total_cores      => 4,
      :cpu_sockets          => 4,
      :annotation           => nil,
      :memory_mb            => 2024
    )

    expect(v.hardware.disks.size).to eq(1)
    disk = v.hardware.disks.find_by(:device_name => "vm1_Disk1")
    expect(disk).to have_attributes(
      :device_name     => "vm1_Disk1",
      :device_type     => "disk",
      :controller_type => "virtio",
      :present         => true,
      :filename        => "af578e0e-b222-4754-aefc-879bf37eacec",
      :location        => "0",
      :size            => 6.gigabytes,
      :size_on_disk    => 2_987_851_776,
      :mode            => "persistent",
      :disk_type       => "thin",
      :start_connected => true
    )
    expect(disk.storage).to eq(@storage)

    expect(v.hardware.guest_devices.size).to eq(1)
    expect(v.hardware.nics.size).to eq(1)
    nic = v.hardware.nics.find_by(:device_name => "nic1")
    expect(nic).to have_attributes(
      :uid_ems         => "6a538d86-38a2-4ac9-98f5-9d401a596e93",
      :device_name     => "nic1",
      :device_type     => "ethernet",
      :controller_type => "ethernet",
      :present         => true,
      :start_connected => true,
      :address         => "00:1a:4a:16:01:51"
    )
    # nic.lan.should == @lan # TODO: Hook up this connection

    expect(v.parent_datacenter).to have_attributes(
      :ems_ref     => "/api/datacenters/b60b3daa-dcbd-40c9-8d09-3fc08c91f5d1",
      :ems_ref_obj => "/api/datacenters/b60b3daa-dcbd-40c9-8d09-3fc08c91f5d1",
      :uid_ems     => "b60b3daa-dcbd-40c9-8d09-3fc08c91f5d1",
      :name        => "dc1",
      :type        => "Datacenter",

      :folder_path => "Datacenters/dc1"
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
      :uid_ems     => "b60b3daa-dcbd-40c9-8d09-3fc08c91f5d1_vm",
      :name        => "vm",
      :type        => nil,

      :folder_path => "Datacenters/dc1/vm"
    )
  end

  def assert_specific_vm_powered_off
    v = ManageIQ::Providers::Redhat::InfraManager::Vm.find_by(:name => "vm2")
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "/api/vms/072093dc-3492-4cb1-b240-dbf88a8f4fbf",
      :ems_ref_obj           => "/api/vms/072093dc-3492-4cb1-b240-dbf88a8f4fbf",
      :uid_ems               => "072093dc-3492-4cb1-b240-dbf88a8f4fbf",
      :vendor                => "redhat",
      :raw_power_state       => "down",
      :power_state           => "off",
      :location              => "072093dc-3492-4cb1-b240-dbf88a8f4fbf.ovf",
      :tools_status          => nil,
      :boot_time             => nil,
      :standby_action        => nil,
      :connection_state      => "connected",
      :cpu_affinity          => nil,
      :memory_reserve        => 1024,
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
      :product_name => "other"
    )

    expect(v.custom_attributes.size).to eq(0)

    expect(v.snapshots.size).to eq(2)
    snapshot = v.snapshots.detect { |s| s.current == 1 } # TODO: Fix this boolean column
    expect(snapshot).to have_attributes(
      :uid         => "677a1c40-8112-4e4a-bd03-c430e7505912",
      :parent_uid  => "ef7b7d35-c7b8-4270-8ec7-b85047a50bdc",
      :uid_ems     => "677a1c40-8112-4e4a-bd03-c430e7505912",
      :name        => "22",
      :description => "22",
      :current     => 1,
      :total_size  => nil,
      :filename    => nil
    )
    snapshot = snapshot.parent # TODO: THIS IS COMPLETELY WRONG
    expect(snapshot).to have_attributes(
      :uid         => "ef7b7d35-c7b8-4270-8ec7-b85047a50bdc",
      :parent_uid  => nil,
      :uid_ems     => "ef7b7d35-c7b8-4270-8ec7-b85047a50bdc",
      :name        => "Active VM",
      :description => "Active VM",
      :current     => 0
    )
    expect(snapshot.parent).to be_nil

    expect(v.hardware).to have_attributes(
      :guest_os           => "other",
      :guest_os_full_name => nil,
      :bios               => nil,
      :cpu_sockets        => 1,
      :annotation         => nil,
      :memory_mb          => 1024
    )

    expect(v.hardware.disks.size).to eq(1)
    disk = v.hardware.disks.find_by(:device_name => "vm2_Disk1")
    expect(disk).to have_attributes(
      :device_name     => "vm2_Disk1",
      :device_type     => "disk",
      :controller_type => "virtio",
      :present         => true,
      :filename        => "9a3e866c-4497-46df-801a-d1739c31c69d",
      :location        => "0",
      :size            => 5.gigabytes,
      :mode            => "persistent",
      :disk_type       => "thin",
      :start_connected => true
    )
    expect(disk.storage).to eq(@storage)

    expect(v.hardware.guest_devices.size).to eq(1)
    expect(v.hardware.nics.size).to eq(1)
    nic = v.hardware.nics.find_by(:device_name => "nic1")
    expect(nic).to have_attributes(
      :uid_ems         => "fdc2d708-01d1-4aa4-8b53-d64177181e2e",
      :device_name     => "nic1",
      :device_type     => "ethernet",
      :controller_type => "ethernet",
      :present         => true,
      :start_connected => true,
      :address         => "00:1a:4a:16:01:52"
    )
    expect(nic.lan).to     be_nil
    expect(nic.network).to be_nil

    expect(v.hardware.networks.size).to eq(0)

    expect(v.parent_datacenter).to have_attributes(
      :ems_ref     => "/api/datacenters/b60b3daa-dcbd-40c9-8d09-3fc08c91f5d1",
      :ems_ref_obj => "/api/datacenters/b60b3daa-dcbd-40c9-8d09-3fc08c91f5d1",
      :uid_ems     => "b60b3daa-dcbd-40c9-8d09-3fc08c91f5d1",
      :name        => "dc1",
      :type        => "Datacenter",

      :folder_path => "Datacenters/dc1"
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
      :uid_ems     => "b60b3daa-dcbd-40c9-8d09-3fc08c91f5d1_vm",
      :name        => "vm",
      :type        => nil,

      :folder_path => "Datacenters/dc1/vm"
    )
  end

  def assert_specific_template
    v = ManageIQ::Providers::Redhat::InfraManager::Template.find_by(:name => "template_cd1")
    expect(v).to have_attributes(
      :template              => true,
      :ems_ref               => "/api/templates/785e845e-baa0-4812-8a8c-467f37ad6c79",
      :ems_ref_obj           => "/api/templates/785e845e-baa0-4812-8a8c-467f37ad6c79",
      :uid_ems               => "785e845e-baa0-4812-8a8c-467f37ad6c79",
      :vendor                => "redhat",
      :power_state           => "never",
      :location              => "785e845e-baa0-4812-8a8c-467f37ad6c79.ovf",
      :tools_status          => nil,
      :boot_time             => nil,
      :standby_action        => nil,
      :connection_state      => "connected",
      :cpu_affinity          => nil,
      :memory_reserve        => 4024,
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
      :product_name => "other"
    )

    expect(v.custom_attributes.size).to eq(0)
    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to have_attributes(
      :guest_os             => "other",
      :guest_os_full_name   => nil,
      :bios                 => nil,
      :cpu_sockets          => 4,
      :cpu_cores_per_socket => 1,
      :cpu_total_cores      => 4,
      :annotation           => nil,
      :memory_mb            => 4024
    )

    expect(v.hardware.disks.size).to eq(1)
    disk = v.hardware.disks.first
    expect(disk).to have_attributes(
      :device_name     => "vm1_Disk1",
      :device_type     => "disk",
      :controller_type => "virtio",
      :present         => true,
      :filename        => "7917730e-39fb-4da4-9256-da652c33e5b6",
      :location        => "0",
      :size            => 6.gigabytes,
      :mode            => "persistent",
      :disk_type       => "thin",
      :start_connected => true
    )
    expect(disk.storage).to eq(@storage)

    expect(v.hardware.guest_devices.size).to eq(1)
    expect(v.hardware.nics.size).to eq(1)
    expect(v.hardware.networks.size).to eq(0)

    expect(v.parent_datacenter).to have_attributes(
      :ems_ref     => "/api/datacenters/b60b3daa-dcbd-40c9-8d09-3fc08c91f5d1",
      :ems_ref_obj => "/api/datacenters/b60b3daa-dcbd-40c9-8d09-3fc08c91f5d1",
      :uid_ems     => "b60b3daa-dcbd-40c9-8d09-3fc08c91f5d1",
      :name        => "dc1",
      :type        => "Datacenter",

      :folder_path => "Datacenters/dc1"
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
      :uid_ems     => "b60b3daa-dcbd-40c9-8d09-3fc08c91f5d1_vm",
      :name        => "vm",
      :type        => nil,

      :folder_path => "Datacenters/dc1/vm"
    )
  end

  def assert_relationship_tree
    expect(@ems.descendants_arranged).to match_relationship_tree(
      [EmsFolder, "Datacenters", {:hidden => true}] => {
        [Datacenter, "dc1"]     => {
          [EmsFolder, "host", {:hidden => true}] => {
            [EmsCluster, "cc1"]   => {
              [ResourcePool, "Default for Cluster cc1"] => {
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "vm1"] => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "vm2"] => {},
              }
            },
            [EmsCluster, "dccc2"] => {
              [ResourcePool, "Default for Cluster dccc2"] => {},
            }
          },
          [EmsFolder, "vm", {:hidden => true}]   => {
            [ManageIQ::Providers::Redhat::InfraManager::Template, "template_cd1"] => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "vm1"]                => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "vm2"]                => {}
          }
        },
        [Datacenter, "Default"] => {
          [EmsFolder, "host", {:hidden => true}] => {
            [EmsCluster, "Default"] => {
              [ResourcePool, "Default for Cluster Default"] => {
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "external-manageiq"]   => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "external-as"]         => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "vmdc1"]               => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "vm3"]                 => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "external-yo"]         => {},
                [ManageIQ::Providers::Redhat::InfraManager::Vm, "external-test_se121"] => {},
              }
            }
          },
          [EmsFolder, "vm", {:hidden => true}]   => {
            [ManageIQ::Providers::Redhat::InfraManager::Template, "template_ex_default"] => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "external-manageiq"]         => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "external-as"]               => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "vmdc1"]                     => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "vm3"]                       => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "external-yo"]               => {},
            [ManageIQ::Providers::Redhat::InfraManager::Vm, "external-test_se121"]       => {},
          },
        }
      }
    )
  end
end
