require "spec_helper"

describe ManageIQ::Providers::Oracle::InfraManager::Refresher do
  before(:each) do
    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_oracle, :zone => zone, :hostname => '172.16.95.57', :ipaddress => '172.16.95.57', :port => 7002)
    @ems.update_authentication(:default => {:userid => 'admin', :password => 'password'})
  end

  it "will perform a full refresh" do
    VCR.use_cassette("#{described_class.name.underscore}") do
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
    EmsFolder.count.should == 4
    EmsCluster.count.should == 1
    Host.count.should == 1
    ResourcePool.count.should == 1
    VmOrTemplate.count.should == 5
    Vm.count.should == 4
    MiqTemplate.count.should == 1
    Storage.count.should == 1

    CustomAttribute.count.should == 0
    CustomizationSpec.count.should == 0
    Disk.count.should == 5
    GuestDevice.count.should == 7
    Hardware.count.should == 6
    Lan.count.should == 1
    MiqScsiLun.count.should == 0
    MiqScsiTarget.count.should == 0
    Network.count.should == 1
    OperatingSystem.count.should == 6
    Snapshot.count.should == 0
    Switch.count.should == 1
    SystemService.count.should == 0

    Relationship.count.should == 16
  end

  def assert_ems
    @ems.should have_attributes(
      :api_version => "3.3.3.1085",
      :uid_ems     => nil
    )

    @ems.ems_folders.size.should == 4
    @ems.ems_clusters.size.should == 1
    @ems.resource_pools.size.should == 1
    @ems.storages.size.should == 0
    @ems.hosts.size.should == 1
    @ems.vms_and_templates.size.should == 5
    @ems.vms.size.should == 4
    @ems.miq_templates.size.should == 1

    @ems.customization_specs.size.should == 0
  end

  def assert_specific_cluster
    @cluster = EmsCluster.find_by_name("test-pool Cluster")
    @cluster.should have_attributes(
      :uid_ems                 => "0004fb0000020000b5995e9c15a0a4a5_cluster",
      :name                    => "test-pool Cluster",
      :ha_enabled              => nil,
      :ha_admit_control        => nil,
      :ha_max_failures         => nil,
      :drs_enabled             => nil,
      :drs_automation_level    => nil,
      :drs_migration_threshold => nil
    )

    @cluster.all_resource_pools_with_default.size.should == 1
    @default_rp = @cluster.default_resource_pool
    @default_rp.should have_attributes(
      :ems_ref               => nil,
      :ems_ref_obj           => nil,
      :uid_ems               => "0004fb0000020000b5995e9c15a0a4a5",
      :name                  => "test-pool",
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
    @storage = Storage.find_by_name("test-pool")
    @storage.should have_attributes(
      :ems_ref                       => "/Repository/0004fb00000300003076225fcb290271",
      :ems_ref_obj                   => "/Repository/0004fb00000300003076225fcb290271",
      :name                          => "test-pool",
      :store_type                    => "ISCSI",
      :total_space                   => 187709784064,
      :free_space                    => 169837854720,
      :uncommitted                   => 169837854720,
      :multiplehostaccess            => 1,
      :location                      => "/dev/mapper/OVM_SYS_REPO_PART_35002538da0269d57",
      :directory_hierarchy_supported => nil,
      :thin_provisioning_supported   => nil,
      :raw_disk_mappings_supported   => nil
    )
  end

  def assert_specific_host
    @host = ManageIQ::Providers::Oracle::InfraManager::Host.find_by_name("oracle-vm-server")
    @host.should have_attributes(
      :ems_ref          => "/Server/03:aa:02:fc:04:14:05:e3:f5:06:de:07:00:08:00:09",
      :ems_ref_obj      => "/Server/03:aa:02:fc:04:14:05:e3:f5:06:de:07:00:08:00:09",
      :name             => "oracle-vm-server",
      :hostname         => "oracle-vm-server",
      :ipaddress        => "172.16.92.64",
      :uid_ems          => "03:aa:02:fc:04:14:05:e3:f5:06:de:07:00:08:00:09",
      :vmm_vendor       => "Oracle",
      :vmm_version      => "3.3.3",
      :vmm_product      => "oraclevm",
      :vmm_buildnumber  => "1085",
      :power_state      => "on",
      :connection_state => "connected"
    )

    @host.ems_cluster.should == @cluster
    @host.storages.size.should == 0

    @host.operating_system.should have_attributes(
      :name         => "oracle-vm-server",
      :product_name => "linux",
      :version      => nil,
      :build_number => nil,
      :product_type => nil
    )

    @host.system_services.size.should == 0

    @host.switches.size.should == 1
    switch = @host.switches.find_by_name("172.16.0.0")
    switch.should have_attributes(
      :uid_ems           => "ac100000",
      :name              => "172.16.0.0",
      :ports             => nil,
      :allow_promiscuous => nil,
      :forged_transmits  => nil,
      :mac_changes       => nil
    )

    switch.lans.size.should == 1
    @lan = switch.lans.find_by_name("172.16.0.0")
    @lan.should have_attributes(
      :uid_ems                    => "ac100000",
      :name                       => "172.16.0.0",
      :tag                        => nil,
      :allow_promiscuous          => nil,
      :forged_transmits           => nil,
      :mac_changes                => nil,
      :computed_allow_promiscuous => nil,
      :computed_forged_transmits  => nil,
      :computed_mac_changes       => nil
    )

    @host.hardware.should have_attributes(
      :cpu_speed            => 0,
      :cpu_type             => "Intel(R) Core(TM) i7-4790 CPU @ 3.60GHz",
      :manufacturer         => "GenuineIntel",
      :model                => "Intel(R) Core(TM) i7-4790 CPU @ 3.60GHz",
      :number_of_nics       => nil,
      :memory_mb            => 16264,
      :memory_console       => nil,
      :cpu_sockets          => 1,
      :cpu_total_cores      => 8,
      :cpu_cores_per_socket => 8,
      :guest_os             => nil,
      :guest_os_full_name   => nil,
      :vmotion_enabled      => nil,
      :cpu_usage            => nil,
      :memory_usage         => nil
    )

    @host.hardware.networks.size.should == 1
    network = @host.hardware.networks.find_by_description("bond0 on oracle-vm-server")
    network.should have_attributes(
      :description  => "bond0 on oracle-vm-server",
      :dhcp_enabled => nil,
      :ipaddress    => "172.16.92.64",
      :subnet_mask  => "255.255.0.0"
    )

    @host.hardware.guest_devices.size.should == 2

    @host.hardware.nics.size.should == 2

    nic1 = @host.hardware.nics.find_by_device_name("bond0 on oracle-vm-server")
    nic1.should have_attributes(
      :uid_ems         => "0004fb0000200000a0cc6d2cfde52f39",
      :device_name     => "bond0 on oracle-vm-server",
      :device_type     => "ethernet",
      :location        => "bond0",
      :present         => true,
      :controller_type => "ethernet"
    )
    nic1.switch.should == switch
    nic1.network.should == network

    nic2 = @host.hardware.nics.find_by_device_name("eth0 on oracle-vm-server")
    nic2.should have_attributes(
      :uid_ems         => "0004fb0000200000bd65b4a15a3af1c8",
      :device_name     => "eth0 on oracle-vm-server",
      :device_type     => "ethernet",
      :location        => "eth0",
      :present         => true,
      :controller_type => "ethernet"
    )
    nic2.switch.should be_nil
    nic2.network.should be_nil

    @host.hardware.storage_adapters.size.should == 0
  end

  def assert_specific_vm_powered_on
    v = ManageIQ::Providers::Oracle::InfraManager::Vm.find_by_name("test")
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "/Vm/0004fb00000600002d441b5e6431b729",
      :ems_ref_obj           => "/Vm/0004fb00000600002d441b5e6431b729",
      :uid_ems               => "0004fb00000600002d441b5e6431b729",
      :vendor                => "Oracle",
      :raw_power_state       => "RUNNING",
      :power_state           => "on",
      :location              => "test",
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
    v.ems_cluster.should == @cluster
    v.parent_resource_pool.should == @default_rp
    v.host.should.nil?
    v.storages.should == [@storage]
    v.storage.should == @storage

    v.operating_system.should have_attributes(
      :product_name => "Other Linux"
    )

    v.custom_attributes.size.should == 0

    v.snapshots.size.should == 0

    v.hardware.should have_attributes(
      :guest_os           => "Other Linux",
      :guest_os_full_name => nil,
      :bios               => nil,
      :cpu_sockets        => 1,
      :annotation         => "",
      :memory_mb          => 1024
    )

    v.hardware.disks.size.should == 1
    disk = v.hardware.disks.find_by_device_name("test")
    disk.should have_attributes(
      :device_name     => "test",
      :device_type     => "disk",
      :controller_type => "Block",
      :present         => true,
      :filename        => "0004fb000012000083f79193eb5f331e.img",
      :location        => "/VirtualDisks/0004fb000012000083f79193eb5f331e.img",
      :size            => 10737418240,
      :mode            => "persistent",
      :disk_type       => "thick",
      :start_connected => true
    )
    disk.storage.should == @storage

    v.hardware.guest_devices.size.should == 1
    v.hardware.nics.size.should == 1
    nic = v.hardware.nics.find_by_device_name("00:21:f6:3a:60:bc")
    nic.should have_attributes(
      :uid_ems         => "0004fb0000070000f35dc14d694dadc9",
      :device_name     => "00:21:f6:3a:60:bc",
      :device_type     => "ethernet",
      :controller_type => "ethernet",
      :present         => true,
      :start_connected => true,
      :address         => "00:21:f6:3a:60:bc"
    )
    nic.lan.should == @lan

    v.hardware.networks.size.should == 0
    network = v.hardware.networks.first
    network.should be_nil

    v.parent_datacenter.should have_attributes(
      :uid_ems       => "default_dc",
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
      :uid_ems       => "default_dc_vm",
      :name          => "vm",
      :is_datacenter => false,

      :folder_path   => "Datacenters/Default/vm"
    )
  end

  def assert_specific_vm_powered_off
    v = ManageIQ::Providers::Oracle::InfraManager::Vm.find_by_name("Test3.0")
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "/Vm/0004fb00000600006f8e65a5d245ea0c",
      :ems_ref_obj           => "/Vm/0004fb00000600006f8e65a5d245ea0c",
      :uid_ems               => "0004fb00000600006f8e65a5d245ea0c",
      :vendor                => "Oracle",
      :raw_power_state       => "STOPPED",
      :power_state           => "off",
      :location              => "Test3.0",
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
    v.ems_cluster.should == @cluster
    v.parent_resource_pool.should == @default_rp
    v.host.should == @host
    v.storages.should == [@storage]
    v.storage.should == @storage

    v.operating_system.should have_attributes(
      :product_name => "Other Linux"
    )

    v.custom_attributes.size.should == 0

    v.snapshots.size.should == 0

    v.hardware.should have_attributes(
      :guest_os           => "Other Linux",
      :guest_os_full_name => nil,
      :bios               => nil,
      :cpu_sockets        => 1,
      :annotation         => "",
      :memory_mb          => 512
    )

    v.hardware.disks.size.should == 1
    disk = v.hardware.disks.find_by_device_name("Test3disk")
    disk.should have_attributes(
      :device_name     => "Test3disk",
      :device_type     => "disk",
      :controller_type => "Block",
      :present         => true,
      :filename        => "0004fb0000120000be8645e8d8b9bf65.img",
      :location        => "/VirtualDisks/0004fb0000120000be8645e8d8b9bf65.img",
      :size            => 7516192768,
      :mode            => "persistent",
      :disk_type       => "thick",
      :start_connected => true
    )
    disk.storage.should == @storage

    v.hardware.guest_devices.size.should == 1
    v.hardware.nics.size.should == 1
    nic = v.hardware.nics.find_by_device_name("00:21:f6:0f:d6:2c")
    nic.should have_attributes(
      :uid_ems         => "0004fb0000070000d1272c5187d1bef0",
      :device_name     => "00:21:f6:0f:d6:2c",
      :device_type     => "ethernet",
      :controller_type => "ethernet",
      :present         => true,
      :start_connected => true,
      :address         => "00:21:f6:0f:d6:2c"
    )
    nic.lan.should == @lan
    nic.network.should be_nil

    v.hardware.networks.size.should == 0

    v.parent_datacenter.should have_attributes(
      :uid_ems       => "default_dc",
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
      :uid_ems       => "default_dc_vm",
      :name          => "vm",
      :is_datacenter => false,

      :folder_path   => "Datacenters/Default/vm"
    )
  end

  def assert_specific_template
    v = ManageIQ::Providers::Oracle::InfraManager::Template.find_by_name("centos-7-template.0")
    v.should have_attributes(
      :template              => true,
      :ems_ref               => "/Vm/0004fb0000060000bc56cffe6e9aba7a",
      :ems_ref_obj           => "/Vm/0004fb0000060000bc56cffe6e9aba7a",
      :uid_ems               => "0004fb0000060000bc56cffe6e9aba7a",
      :vendor                => "Oracle",
      :power_state           => "never",
      :location              => "centos-7-template.0",
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
    v.ems_cluster.should be_nil
    v.parent_resource_pool.should be_nil
    v.host.should be_nil
    v.storages.should == [@storage]
    v.storage.should == @storage

    v.operating_system.should have_attributes(
      :product_name => "Other Linux"
    )

    v.custom_attributes.size.should == 0
    v.snapshots.size.should == 0

    v.hardware.should have_attributes(
      :guest_os             => "Other Linux",
      :guest_os_full_name   => nil,
      :bios                 => nil,
      :cpu_sockets          => 1,
      :cpu_cores_per_socket => 1,
      :cpu_total_cores      => 1,
      :annotation           => "",
      :memory_mb            => 1024
    )

    v.hardware.disks.size.should == 1
    disk = v.hardware.disks.find_by_device_name("test (2)")
    disk.should have_attributes(
      :device_name     => "test (2)",
      :device_type     => "disk",
      :controller_type => "Block",
      :present         => true,
      :filename        => "0004fb00001200006b0be3e9eece06c8.img",
      :location        => "/VirtualDisks/0004fb00001200006b0be3e9eece06c8.img",
      :size            => 10737418240,
      :mode            => "persistent",
      :disk_type       => "thick",
      :start_connected => true
    )
    disk.storage.should == @storage

    v.hardware.guest_devices.size.should == 1
    v.hardware.nics.size.should == 1
    v.hardware.networks.size.should == 0

    # Oracle template does not have server_pool_id and therefore no cluster
    v.parent_datacenter.should be_nil
    v.parent_folder.should be_nil

    v.parent_blue_folder.should have_attributes(
      :ems_ref       => nil,
      :ems_ref_obj   => nil,
      :uid_ems       => "default_dc_vm",
      :name          => "vm",
      :is_datacenter => false,

      :folder_path   => "Datacenters/Default/vm"
    )
  end

  def assert_relationship_tree
    @ems.descendants_arranged.should match_relationship_tree(
      [EmsFolder, "Datacenters", {:is_datacenter => false}] => {
        [EmsFolder, "Default", {:is_datacenter => true}] => {
          [EmsFolder, "host", {:is_datacenter => false}] => {
            [EmsCluster, "test-pool Cluster"] => {
              [ResourcePool, "test-pool", {:is_default => true}] => {
                [ManageIQ::Providers::Oracle::InfraManager::Vm, "Test3.0"]  => {},
                [ManageIQ::Providers::Oracle::InfraManager::Vm, "Test4.0"]  => {},
                [ManageIQ::Providers::Oracle::InfraManager::Vm, "test"]     => {},
                [ManageIQ::Providers::Oracle::InfraManager::Vm, "test2.0"]  => {}
              }
            }
          },
          [EmsFolder, "vm", {:is_datacenter => false}]   => {
            [ManageIQ::Providers::Oracle::InfraManager::Template, "centos-7-template.0"]  => {},
            [ManageIQ::Providers::Oracle::InfraManager::Vm, "Test3.0"]            => {},
            [ManageIQ::Providers::Oracle::InfraManager::Vm, "Test4.0"]  => {},
            [ManageIQ::Providers::Oracle::InfraManager::Vm, "test"]               => {},
            [ManageIQ::Providers::Oracle::InfraManager::Vm, "test2.0"]            => {}
          }
        }
      }
    )
  end
end
