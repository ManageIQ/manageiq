describe ManageIQ::Providers::Oracle::InfraManager::Refresher do
  before(:each) do
    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_oracle, :zone => zone, :hostname => '172.16.95.57', :ipaddress => '172.16.95.57', :port => 7002)
    @ems.update_authentication(:default => {:userid => 'admin', :password => 'password'})
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:oraclevm)
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
    expect(ExtManagementSystem.count).to eq(1)
    expect(EmsFolder.count).to eq(4)
    expect(EmsCluster.count).to eq(1)
    expect(Host.count).to eq(1)
    expect(ResourcePool.count).to eq(1)
    expect(VmOrTemplate.count).to eq(5)
    expect(Vm.count).to eq(4)
    expect(MiqTemplate.count).to eq(1)
    expect(Storage.count).to eq(1)

    expect(CustomAttribute.count).to eq(0)
    expect(CustomizationSpec.count).to eq(0)
    expect(Disk.count).to eq(5)
    expect(GuestDevice.count).to eq(7)
    expect(Hardware.count).to eq(6)
    expect(Lan.count).to eq(1)
    expect(MiqScsiLun.count).to eq(0)
    expect(MiqScsiTarget.count).to eq(0)
    expect(Network.count).to eq(1)
    expect(OperatingSystem.count).to eq(6)
    expect(Snapshot.count).to eq(0)
    expect(Switch.count).to eq(1)
    expect(SystemService.count).to eq(0)

    expect(Relationship.count).to eq(16)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :api_version => "3.3.3.1085",
      :uid_ems     => nil
    )

    expect(@ems.ems_folders.size).to eq(4)
    expect(@ems.ems_clusters.size).to eq(1)
    expect(@ems.resource_pools.size).to eq(1)
    expect(@ems.storages.size).to eq(0)
    expect(@ems.hosts.size).to eq(1)
    expect(@ems.vms_and_templates.size).to eq(5)
    expect(@ems.vms.size).to eq(4)
    expect(@ems.miq_templates.size).to eq(1)

    expect(@ems.customization_specs.size).to eq(0)
  end

  def assert_specific_cluster
    @cluster = EmsCluster.find_by_name("test-pool Cluster")
    expect(@cluster).to have_attributes(
      :uid_ems                 => "0004fb0000020000b5995e9c15a0a4a5_cluster",
      :name                    => "test-pool Cluster",
      :ha_enabled              => nil,
      :ha_admit_control        => nil,
      :ha_max_failures         => nil,
      :drs_enabled             => nil,
      :drs_automation_level    => nil,
      :drs_migration_threshold => nil
    )

    expect(@cluster.all_resource_pools_with_default.size).to eq(1)
    @default_rp = @cluster.default_resource_pool
    expect(@default_rp).to have_attributes(
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
    expect(@storage).to have_attributes(
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
    expect(@host).to have_attributes(
      :ems_ref          => "/Server/03:aa:02:fc:04:14:05:e3:f5:06:de:07:00:08:00:09",
      :ems_ref_obj      => "/Server/03:aa:02:fc:04:14:05:e3:f5:06:de:07:00:08:00:09",
      :name             => "oracle-vm-server",
      :hostname         => "oracle-vm-server",
      :ipaddress        => "172.16.92.64",
      :uid_ems          => "03:aa:02:fc:04:14:05:e3:f5:06:de:07:00:08:00:09",
      :vmm_vendor       => "oracle",
      :vmm_version      => "3.3.3",
      :vmm_product      => "oraclevm",
      :vmm_buildnumber  => "1085",
      :power_state      => "on",
      :connection_state => "connected"
    )

    expect(@host.ems_cluster).to eq(@cluster)
    expect(@host.storages.size).to eq(0)

    expect(@host.operating_system).to have_attributes(
      :name         => "oracle-vm-server",
      :product_name => "linux",
      :version      => nil,
      :build_number => nil,
      :product_type => nil
    )

    expect(@host.system_services.size).to eq(0)

    expect(@host.switches.size).to eq(1)
    switch = @host.switches.find_by_name("172.16.0.0")
    expect(switch).to have_attributes(
      :uid_ems           => "ac100000",
      :name              => "172.16.0.0",
      :ports             => nil,
      :allow_promiscuous => nil,
      :forged_transmits  => nil,
      :mac_changes       => nil
    )

    expect(switch.lans.size).to eq(1)
    @lan = switch.lans.find_by_name("172.16.0.0")
    expect(@lan).to have_attributes(
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

    expect(@host.hardware).to have_attributes(
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

    expect(@host.hardware.networks.size).to eq(1)
    network = @host.hardware.networks.find_by_description("bond0 on oracle-vm-server")
    expect(network).to have_attributes(
      :description  => "bond0 on oracle-vm-server",
      :dhcp_enabled => nil,
      :ipaddress    => "172.16.92.64",
      :subnet_mask  => "255.255.0.0"
    )

    expect(@host.hardware.guest_devices.size).to eq(2)

    expect(@host.hardware.nics.size).to eq(2)

    nic1 = @host.hardware.nics.find_by_device_name("bond0 on oracle-vm-server")
    expect(nic1).to have_attributes(
      :uid_ems         => "0004fb0000200000a0cc6d2cfde52f39",
      :device_name     => "bond0 on oracle-vm-server",
      :device_type     => "ethernet",
      :location        => "bond0",
      :present         => true,
      :controller_type => "ethernet"
    )
    expect(nic1.switch).to eq(switch)
    expect(nic1.network).to eq(network)

    nic2 = @host.hardware.nics.find_by_device_name("eth0 on oracle-vm-server")
    expect(nic2).to have_attributes(
      :uid_ems         => "0004fb0000200000bd65b4a15a3af1c8",
      :device_name     => "eth0 on oracle-vm-server",
      :device_type     => "ethernet",
      :location        => "eth0",
      :present         => true,
      :controller_type => "ethernet"
    )
    expect(nic2.switch).to be_nil
    expect(nic2.network).to be_nil

    expect(@host.hardware.storage_adapters.size).to eq(0)
  end

  def assert_specific_vm_powered_on
    v = ManageIQ::Providers::Oracle::InfraManager::Vm.find_by_name("test")
    expect(v).to have_attributes(
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

    expect(v.ext_management_system).to eq(@ems)
    expect(v.ems_cluster).to eq(@cluster)
    expect(v.parent_resource_pool).to eq(@default_rp)
    expect(v.host).to eq(@host)
    expect(v.storages).to eq([@storage])
    expect(v.storage).to eq(@storage)

    expect(v.operating_system).to have_attributes(
      :product_name => "Other Linux"
    )

    expect(v.custom_attributes.size).to eq(0)

    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to have_attributes(
      :guest_os           => "Other Linux",
      :guest_os_full_name => nil,
      :bios               => nil,
      :cpu_sockets        => 1,
      :annotation         => "",
      :memory_mb          => 1024
    )

    expect(v.hardware.disks.size).to eq(1)
    disk = v.hardware.disks.find_by_device_name("test")
    expect(disk).to have_attributes(
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
    expect(disk.storage).to eq(@storage)

    expect(v.hardware.guest_devices.size).to eq(1)
    expect(v.hardware.nics.size).to eq(1)
    nic = v.hardware.nics.find_by_device_name("00:21:f6:3a:60:bc")
    expect(nic).to have_attributes(
      :uid_ems         => "0004fb0000070000f35dc14d694dadc9",
      :device_name     => "00:21:f6:3a:60:bc",
      :device_type     => "ethernet",
      :controller_type => "ethernet",
      :present         => true,
      :start_connected => true,
      :address         => "00:21:f6:3a:60:bc"
    )
    expect(nic.lan).to eq(@lan)

    expect(v.hardware.networks.size).to eq(0)
    network = v.hardware.networks.first
    expect(network).to be_nil

    expect(v.parent_datacenter).to have_attributes(
      :uid_ems       => "default_dc",
      :name          => "Default",
      :is_datacenter => true,

      :folder_path   => "Datacenters/Default"
    )

    expect(v.parent_folder).to have_attributes(
      :ems_ref       => nil,
      :ems_ref_obj   => nil,
      :uid_ems       => "root_dc",
      :name          => "Datacenters",
      :is_datacenter => false,

      :folder_path   => "Datacenters"
    )

    expect(v.parent_blue_folder).to have_attributes(
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
    expect(v).to have_attributes(
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

    expect(v.ext_management_system).to eq(@ems)
    expect(v.ems_cluster).to eq(@cluster)
    expect(v.parent_resource_pool).to eq(@default_rp)
    expect(v.host).to eq(@host)
    expect(v.storages).to eq([@storage])
    expect(v.storage).to eq(@storage)

    expect(v.operating_system).to have_attributes(
      :product_name => "Other Linux"
    )

    expect(v.custom_attributes.size).to eq(0)

    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to have_attributes(
      :guest_os           => "Other Linux",
      :guest_os_full_name => nil,
      :bios               => nil,
      :cpu_sockets        => 1,
      :annotation         => "",
      :memory_mb          => 512
    )

    expect(v.hardware.disks.size).to eq(1)
    disk = v.hardware.disks.find_by_device_name("Test3disk")
    expect(disk).to have_attributes(
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
    expect(disk.storage).to eq(@storage)

    expect(v.hardware.guest_devices.size).to eq(1)
    expect(v.hardware.nics.size).to eq(1)
    nic = v.hardware.nics.find_by_device_name("00:21:f6:0f:d6:2c")
    expect(nic).to have_attributes(
      :uid_ems         => "0004fb0000070000d1272c5187d1bef0",
      :device_name     => "00:21:f6:0f:d6:2c",
      :device_type     => "ethernet",
      :controller_type => "ethernet",
      :present         => true,
      :start_connected => true,
      :address         => "00:21:f6:0f:d6:2c"
    )
    expect(nic.lan).to eq(@lan)
    expect(nic.network).to be_nil

    expect(v.hardware.networks.size).to eq(0)

    expect(v.parent_datacenter).to have_attributes(
      :uid_ems       => "default_dc",
      :name          => "Default",
      :is_datacenter => true,

      :folder_path   => "Datacenters/Default"
    )

    expect(v.parent_folder).to have_attributes(
      :ems_ref       => nil,
      :ems_ref_obj   => nil,
      :uid_ems       => "root_dc",
      :name          => "Datacenters",
      :is_datacenter => false,

      :folder_path   => "Datacenters"
    )

    expect(v.parent_blue_folder).to have_attributes(
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
    expect(v).to have_attributes(
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

    expect(v.ext_management_system).to eq(@ems)
    expect(v.ems_cluster).to be_nil
    expect(v.parent_resource_pool).to be_nil
    expect(v.host).to be_nil
    expect(v.storages).to eq([@storage])
    expect(v.storage).to eq(@storage)

    expect(v.operating_system).to have_attributes(
      :product_name => "Other Linux"
    )

    expect(v.custom_attributes.size).to eq(0)
    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to have_attributes(
      :guest_os             => "Other Linux",
      :guest_os_full_name   => nil,
      :bios                 => nil,
      :cpu_sockets          => 1,
      :cpu_cores_per_socket => 1,
      :cpu_total_cores      => 1,
      :annotation           => "",
      :memory_mb            => 1024
    )

    expect(v.hardware.disks.size).to eq(1)
    disk = v.hardware.disks.find_by_device_name("test (2)")
    expect(disk).to have_attributes(
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
    expect(disk.storage).to eq(@storage)

    expect(v.hardware.guest_devices.size).to eq(1)
    expect(v.hardware.nics.size).to eq(1)
    expect(v.hardware.networks.size).to eq(0)

    # Oracle template does not have server_pool_id and therefore no cluster
    expect(v.parent_datacenter).to be_nil
    expect(v.parent_folder).to be_nil

    expect(v.parent_blue_folder).to have_attributes(
      :ems_ref       => nil,
      :ems_ref_obj   => nil,
      :uid_ems       => "default_dc_vm",
      :name          => "vm",
      :is_datacenter => false,

      :folder_path   => "Datacenters/Default/vm"
    )
  end

  def assert_relationship_tree
    expect(@ems.descendants_arranged).to match_relationship_tree(
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
