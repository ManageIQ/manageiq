require "spec_helper"
require File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. tools vim_data vim_data_test_helper}))

describe EmsRefresh::Refreshers::VcRefresher do
  before(:each) do
    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_vmware_with_authentication, :zone => zone, :name => "VC41Test-Prod", :hostname => "VC41Test-Prod.MIQTEST.LOCAL", :ipaddress => "192.168.252.14")

    EmsVmware.any_instance.stub(:connect).and_return(FakeMiqVimHandle.new)
    EmsVmware.any_instance.stub(:disconnect).and_return(true)
    EmsVmware.any_instance.stub(:has_credentials?).and_return(true)
  end

  it "will perform a full refresh" do
    EmsRefresh.refresh(@ems)
    @ems.reload

    assert_table_counts
    assert_ems
    assert_specific_cluster
    assert_specific_storage
    assert_specific_host
    assert_specific_vm
    assert_relationship_tree
  end

  def assert_table_counts
    ExtManagementSystem.count.should == 1
    EmsFolder.count.should           == 30
    EmsCluster.count.should          == 1
    Host.count.should                == 4
    ResourcePool.count.should        == 17
    VmOrTemplate.count.should        == 101
    Vm.count.should                  == 92
    MiqTemplate.count.should         == 9
    Storage.count.should             == 50

    CustomAttribute.count.should     == 3
    CustomizationSpec.count.should   == 2
    Disk.count.should                == 421
    GuestDevice.count.should         == 135
    Hardware.count.should            == 105
    Lan.count.should                 == 14
    MiqScsiLun.count.should          == 73
    MiqScsiTarget.count.should       == 73
    Network.count.should             == 75
    OperatingSystem.count.should     == 105
    Snapshot.count.should            == 29
    Switch.count.should              == 8
    SystemService.count.should       == 29

    Relationship.count.should        == 244
    MiqQueue.count.should            == 101
  end

  def assert_ems
    @ems.should have_attributes(
      :api_version => "4.1",
      :uid_ems     => "EF53782F-6F1A-4471-B338-72B27774AFDD"
    )

    @ems.ems_folders.size.should       == 30
    @ems.ems_clusters.size.should      == 1
    @ems.resource_pools.size.should    == 17
    @ems.storages.size.should          == 47
    @ems.hosts.size.should             == 4
    @ems.vms_and_templates.size.should == 101
    @ems.vms.size.should               == 92
    @ems.miq_templates.size.should     == 9

    @ems.customization_specs.size.should == 2
    cspec = @ems.customization_specs.find_by_name("Win2k8Template")
    cspec.should have_attributes(
      :name             => "Win2k8Template",
      :typ              => "Windows",
      :description      => "",
      :last_update_time => Time.parse("2011-05-17T15:54:37Z")
    )
    cspec.spec.should      be_a_kind_of(VimHash)
    cspec.spec.keys.should match_array(["identity", "encryptionKey", "nicSettingMap", "globalIPSettings", "options"])
  end

  def assert_specific_cluster
    @cluster = EmsCluster.find_by_name("Testing-Production Cluster")
    @cluster.should have_attributes(
      :ems_ref                 => "domain-c871",
      :ems_ref_obj             => VimString.new("domain-c871", :ClusterComputeResource, :ManagedObjectReference),
      :uid_ems                 => "domain-c871",
      :name                    => "Testing-Production Cluster",
      :ha_enabled              => false,
      :ha_admit_control        => true,
      :ha_max_failures         => 1,
      :drs_enabled             => true,
      :drs_automation_level    => "fullyAutomated",
      :drs_migration_threshold => 3
    )

    @default_rp = @cluster.default_resource_pool
    @default_rp.should have_attributes(
      :ems_ref               => "resgroup-872",
      :ems_ref_obj           => VimString.new("resgroup-872", :ResourcePool, :ManagedObjectReference),
      :uid_ems               => "resgroup-872",
      :name                  => "Default for Cluster Testing-Production Cluster",
      :memory_reserve        => 102298,
      :memory_reserve_expand => true,
      :memory_limit          => 102298,
      :memory_shares         => 163840,
      :memory_shares_level   => "normal",
      :cpu_reserve           => 29564,
      :cpu_reserve_expand    => true,
      :cpu_limit             => 29564,
      :cpu_shares            => 4000,
      :cpu_shares_level      => "normal",

      :is_default            => true
    )

    @rp = ResourcePool.find_by_ems_ref("resgroup-11340")
    @rp.should have_attributes(
      :ems_ref               => "resgroup-11340",
      :ems_ref_obj           => VimString.new("resgroup-11340", :ResourcePool, :ManagedObjectReference),
      :uid_ems               => "resgroup-11340",
      :name                  => "Joe",
      :memory_reserve        => 0,
      :memory_reserve_expand => true,
      :memory_limit          => -1,
      :memory_shares         => 163840,
      :memory_shares_level   => "normal",
      :cpu_reserve           => 0,
      :cpu_reserve_expand    => true,
      :cpu_limit             => -1,
      :cpu_shares            => 4000,
      :cpu_shares_level      => "normal",

      :is_default            => false
    )

    @cluster.all_resource_pools_with_default.size.should == 15
    @cluster.all_resource_pools_with_default.should include(@rp)
    @cluster.all_resource_pools_with_default.should include(@default_rp)
    @cluster.all_resource_pools.should              include(@rp)
    @cluster.all_resource_pools.should_not          include(@default_rp)
  end

  def assert_specific_storage
    @storage = Storage.find_by_name("StarM1-Prod1 (1)")
    @storage.should have_attributes(
      :ems_ref                       => "datastore-953",
      :ems_ref_obj                   => VimString.new("datastore-953", :Datastore, :ManagedObjectReference),
      :name                          => "StarM1-Prod1 (1)",
      :store_type                    => "VMFS",
      :total_space                   => 524254445568,
      :free_space                    => 85162196992,
      :uncommitted                   => 338640414720,
      :multiplehostaccess            => 1, # TODO: Should this be a boolean column?
      :location                      => "4d3f9f09-38b9b7dc-365d-0010187f00da",
      :directory_hierarchy_supported => true,
      :thin_provisioning_supported   => true,
      :raw_disk_mappings_supported   => true
    )
  end

  def assert_specific_host
    @host = HostVmware.find_by_name("VI4ESXM1.manageiq.com")
    @host.should have_attributes(
      :ems_ref          => "host-9",
      :ems_ref_obj      => VimString.new("host-9", :HostSystem, :ManagedObjectReference),
      :name             => "VI4ESXM1.manageiq.com",
      :hostname         => "VI4ESXM1.manageiq.com",
      :ipaddress        => "192.168.252.13",
      :uid_ems          => "vi4esxm1.manageiq.com",
      :vmm_vendor       => "VMware",
      :vmm_version      => "4.1.0",
      :vmm_product      => "ESXi",
      :vmm_buildnumber  => "260247",
      :power_state      => "on",
      :connection_state => "connected"
    )

    @host.ems_cluster.should   == @cluster
    @host.storages.size.should == 25
    @host.storages.should      include(@storage)

    @host.operating_system.should have_attributes(
      :name         => "VI4ESXM1.manageiq.com",
      :product_name => "ESXi",
      :version      => "4.1.0",
      :build_number => "260247",
      :product_type => "vmnix-x86"
    )

    @host.system_services.size.should == 9
    sys = @host.system_services.find_by_name("DCUI")
    sys.should have_attributes(
      :name         => "DCUI",
      :display_name => "Direct Console UI",
      :running      => true
    )

    @host.switches.size.should == 2
    switch = @host.switches.find_by_name("vSwitch0")
    switch.should have_attributes(
      :uid_ems           => "vSwitch0",
      :name              => "vSwitch0",
      :ports             => 128,
      :allow_promiscuous => false,
      :forged_transmits  => true,
      :mac_changes       => true
    )

    switch.lans.size.should == 3
    @lan = switch.lans.find_by_name("NetApp PG")
    @lan.should have_attributes(
      :uid_ems                    => "NetApp PG",
      :name                       => "NetApp PG",
      :tag                        => "0",
      :allow_promiscuous          => true,
      :forged_transmits           => nil,
      :mac_changes                => nil,
      :computed_allow_promiscuous => true,
      :computed_forged_transmits  => true,
      :computed_mac_changes       => true
    )

    @host.hardware.should have_attributes(
      :cpu_speed          => 2127,
      :cpu_type           => "Intel(R) Xeon(R) CPU           E5506  @ 2.13GHz",
      :manufacturer       => "Dell Inc.",
      :model              => "PowerEdge R410",
      :number_of_nics     => 4,
      :memory_cpu         => 57334,
      :memory_console     => nil,
      :numvcpus           => 2,
      :logical_cpus       => 8,
      :cores_per_socket   => 4,
      :guest_os           => "ESXi",
      :guest_os_full_name => "ESXi",
      :vmotion_enabled    => true,
      :cpu_usage          => 6789,
      :memory_usage       => 36508
    )

    @host.hardware.networks.size.should == 2
    network = @host.hardware.networks.find_by_description("vmnic0")
    network.should have_attributes(
      :description  => "vmnic0",
      :dhcp_enabled => false,
      :ipaddress    => "192.168.252.13",
      :subnet_mask  => "255.255.254.0"
    )

    @host.hardware.guest_devices.size.should == 9

    @host.hardware.nics.size.should == 4
    nic = @host.hardware.nics.find_by_uid_ems("vmnic0")
    nic.should have_attributes(
      :uid_ems         => "vmnic0",
      :device_name     => "vmnic0",
      :device_type     => "ethernet",
      :location        => "01:00.0",
      :present         => true,
      :controller_type => "ethernet"
    )
    nic.switch.should  == switch
    nic.network.should == network

    @host.hardware.storage_adapters.size.should == 5
    adapter = @host.hardware.storage_adapters.find_by_uid_ems("vmhba0")
    adapter.should have_attributes(
      :uid_ems         => "vmhba0",
      :device_name     => "vmhba0",
      :device_type     => "storage",
      :present         => true,
      :iscsi_name      => nil,
      :iscsi_alias     => nil,
      :location        => "00:1f.2",
      :model           => "PowerEdge R410 SATA IDE Controller",
      :controller_type => "Block"
    )

    adapter = @host.hardware.storage_adapters.find_by_uid_ems("vmhba34")
    adapter.should have_attributes(
      :uid_ems         => "vmhba34",
      :device_name     => "vmhba34",
      :device_type     => "storage",
      :present         => true,
      :iscsi_name      => "iqn.1998-01.com.vmware:localhost-6c48eb14",
      :iscsi_alias     => nil,
      :location        => "UNKNOWN - NULL PCI DEV IN VMKCTL",
      :model           => "iSCSI Software Adapter",
      :controller_type => "iSCSI"
    )

    adapter.miq_scsi_targets.size.should == 22
    scsi_target = adapter.miq_scsi_targets.find_by_uid_ems("1")
    scsi_target.should have_attributes(
      :uid_ems     => "1",
      :target      => 1,
      :iscsi_name  => "iqn.1992-08.com.netapp:sn.135107242",
      :iscsi_alias => nil,
      :address     => (VimArray.new << VimString.new("10.1.1.210:3260", nil, :"SOAP::SOAPString"))
    )

    scsi_target.miq_scsi_luns.size.should == 1
    scsi_lun = scsi_target.miq_scsi_luns.first
    scsi_lun.should have_attributes(
      :uid_ems        => "020000000060a980005034442f525a2f7437594a584c554e202020",
      :canonical_name => "naa.60a980005034442f525a2f7437594a58",
      :lun_type       => "disk",
      :device_name    => "/vmfs/devices/disks/naa.60a980005034442f525a2f7437594a58",
      :device_type    => "disk",
      :block          => 692117504,
      :block_size     => 512,
      :capacity       => 346058752,
      :lun            => 0
    )
  end

  def assert_specific_vm
    v = VmVmware.find_by_name("JoeF 4.0.1")
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "vm-11342",
      :ems_ref_obj           => VimString.new("vm-11342", :VirtualMachine, :ManagedObjectReference),
      :uid_ems               => "422f5d16-c048-19e6-3212-e588fbebf7e0",
      :vendor                => "VMware",
      :power_state           => "off",
      :location              => "JoeF 4.0.1/JoeF 4.0.1.vmx",
      :tools_status          => "toolsNotRunning",
      :boot_time             => nil,
      :standby_action        => "checkpoint",
      :connection_state      => "connected",
      :cpu_affinity          => nil,
      :memory_reserve        => 0,
      :memory_reserve_expand => false,
      :memory_limit          => -1,
      :memory_shares         => 40960,
      :memory_shares_level   => "normal",
      :cpu_reserve           => 0,
      :cpu_reserve_expand    => false,
      :cpu_limit             => -1,
      :cpu_shares            => 2000,
      :cpu_shares_level      => "normal"
    )

    v.ext_management_system.should == @ems
    v.ems_cluster.should           == @cluster
    v.parent_resource_pool.should  == @rp
    v.host.should                  == @host
    v.storages.should              == [@storage]
    # v.storage  # TODO: Fix bug where duplication location GUIDs could cause the wrong value to appear.

    v.operating_system.should have_attributes(
      :product_name => "Red Hat Enterprise Linux 5 (64-bit)"
    )

    v.custom_attributes.size.should == 0
    v.snapshots.size.should         == 0

    v.hardware.should have_attributes(
      :guest_os           => "rhel5_64",
      :guest_os_full_name => "Red Hat Enterprise Linux 5 (64-bit)",
      :bios               => "422f5d16-c048-19e6-3212-e588fbebf7e0",
      :numvcpus           => 2,
      :annotation         => nil,
      :memory_cpu         => 4096
    )

    v.hardware.disks.size.should == 5
    disk = v.hardware.disks.find_by_device_name("Hard disk 1")
    disk.should have_attributes(
      :device_name     => "Hard disk 1",
      :device_type     => "disk",
      :controller_type => "scsi",
      :present         => true,
      :filename        => "[StarM1-Prod1 (1)] JoeF 4.0.1/JoeF 4.0.1.vmdk",
      :location        => "0:0",
      :size            => 6442457088,
      :mode            => "persistent",
      :disk_type       => "thin",
      :start_connected => true
    )
    disk.storage.should == @storage

    v.hardware.guest_devices.size.should == 1
    nic = v.hardware.nics.first
    nic.should have_attributes(
      :uid_ems         => "00:50:56:af:00:73",
      :device_name     => "Network adapter 1",
      :device_type     => "ethernet",
      :controller_type => "ethernet",
      :present         => false,
      :start_connected => true,
      :address         => "00:50:56:af:00:73"
    )
    nic.lan.should == @lan

    v.hardware.networks.count.should == 1
    network = v.hardware.networks.first
    network.should have_attributes(
      :hostname    => "joeytester",
      :ipaddress   => "192.168.253.39",
      :ipv6address => nil
    )
    nic.network.should == network

    v.parent_datacenter.should have_attributes(
      :ems_ref       => "datacenter-2",
      :ems_ref_obj   => VimString.new("datacenter-2", :Datacenter, :ManagedObjectReference),
      :uid_ems       => "datacenter-2",
      :name          => "Prod",
      :is_datacenter => true,

      :folder_path   => "Datacenters/Prod"
    )

    v.parent_folder.should have_attributes(
      :ems_ref       => "group-d1",
      :ems_ref_obj   => VimString.new("group-d1", :Folder, :ManagedObjectReference),
      :uid_ems       => "group-d1",
      :name          => "Datacenters",
      :is_datacenter => false,

      :folder_path   => "Datacenters"
    )

    v.parent_blue_folder.should have_attributes(
      :ems_ref       => "group-v11341",
      :ems_ref_obj   => VimString.new("group-v11341", :Folder, :ManagedObjectReference),
      :uid_ems       => "group-v11341",
      :name          => "JFitzgerald",
      :is_datacenter => false,

      :folder_path   => "Datacenters/Prod/vm/JFitzgerald"
    )
  end

  def assert_relationship_tree
    @ems.descendants_arranged.should match_relationship_tree(
      [EmsFolder, "Datacenters", {:is_datacenter => false}] => {
        [EmsFolder, "Dev", {:is_datacenter => true}] => {
          [EmsFolder, "host", {:is_datacenter => false}] => {
            [HostVmwareEsx, "vi4esxm3.manageiq.com"] => {
              [ResourcePool, "Default for Host vi4esxm3.manageiq.com", {:is_default => true}] => {
                [VmVmware, "Dev Cucumber Nightly Appl 2011-05-19"] => {},
                [VmVmware, "DEV-GreggT"] => {},
                [VmVmware, "DEV-GregM"] => {},
                [VmVmware, "DEV-HarpreetK"] => {},
                [VmVmware, "DEV-JoeR"] => {},
                [VmVmware, "DEV-Oleg"] => {},
                [VmVmware, "DEV-RichO"] => {},
                [VmVmware, "GM Nightly Appl 2011-05-19"] => {},
                [VmVmware, "GT Nightly Appl 2011-02-19"] => {},
                [VmVmware, "Hennessy ReiserFS ubuntu server"] => {},
                [VmVmware, "HK-Dev Cucumber Nightly Appl 2011-05-19"] => {},
                [VmVmware, "Jason Nightly Appl 2011-02-19"] => {},
                [VmVmware, "JR- Dev Cucumber Nightly Appl 2011-05-19 - backup"] => {},
                [VmVmware, "JR-cruisecontrol-sandback-testing-April14_backup"] => {},
                [VmVmware, "JR-cruisecontrol-sandbox"] => {},
                [VmVmware, "JR-cruisecontrol-sandbox-for-tina"] => {},
                [VmVmware, "JR-cruisecontrol-sandbox-testing"] => {},
                [VmVmware, "JR-cruisecontrol-sandbox-testing-Apr14"] => {},
                [VmVmware, "JR-Cucumber-Capybara-Akephalos unit tester"] => {},
                [VmVmware, "JR-EVM-4.0.1.14-2"] => {},
                [VmVmware, "JR-EVM-4.0.1.14-28620-centos"] => {},
                [VmVmware, "JR-EVM-4.0.1.14-28620-redhat"] => {},
                [VmVmware, "JR-EVM-4.0.1.14-3"] => {},
                [VmVmware, "JR-EVM-4.0.1.14-redo"] => {},
                [VmVmware, "JR-EVM-4_0_1_9"] => {},
                [VmVmware, "JR-EVM-9.9-27736-2011-04-01"] => {},
                [VmVmware, "JR-EVM3_3_2_32_svn_memprof"] => {},
                [VmVmware, "JR-EVM_3_3_2_32_svn_memprof_for_comparison"] => {},
                [VmVmware, "JR-EVM_4_0_1_8_svn_memprof"] => {},
                [VmVmware, "JR-Region-5-26665-2011-02-22"] => {},
                [VmVmware, "JR-Region-99-26665-2011-02-22"] => {},
                [VmVmware, "JR-SQL2005"] => {},
                [VmVmware, "JR-SQL2005-CLONE"] => {},
                [VmVmware, "JR-svn-nightly-25707-2010-12-26"] => {},
                [VmVmware, "test3"] => {}
              }
            }
          },
          [EmsFolder, "vm", {:is_datacenter => false}] => {
            [EmsFolder, "Discovered virtual machine", {:is_datacenter => false}] => {},
            [EmsFolder, "GreggT", {:is_datacenter => false}] => {
              [VmVmware, "DEV-GreggT"] => {},
              [VmVmware, "GT Nightly Appl 2011-02-19"] => {}
            },
            [EmsFolder, "GregM", {:is_datacenter => false}] => {
              [VmVmware, "DEV-GregM"] => {},
              [VmVmware, "GM Nightly Appl 2011-05-19"] => {}
            },
            [EmsFolder, "Harpreet", {:is_datacenter => false}] => {
              [VmVmware, "DEV-HarpreetK"] => {},
              [VmVmware, "HK-Dev Cucumber Nightly Appl 2011-05-19"] => {}
            },
            [EmsFolder, "Jason", {:is_datacenter => false}] => {
              [VmVmware, "Jason Nightly Appl 2011-02-19"] => {}
            },
            [EmsFolder, "JoeR", {:is_datacenter => false}] => {
              [VmVmware, "DEV-JoeR"] => {},
              [VmVmware, "JR- Dev Cucumber Nightly Appl 2011-05-19 - backup"] => {},
              [VmVmware, "JR-cruisecontrol-sandback-testing-April14_backup"] => {},
              [VmVmware, "JR-cruisecontrol-sandbox"] => {},
              [VmVmware, "JR-cruisecontrol-sandbox-for-tina"] => {},
              [VmVmware, "JR-cruisecontrol-sandbox-testing"] => {},
              [VmVmware, "JR-cruisecontrol-sandbox-testing-Apr14"] => {},
              [VmVmware, "JR-Cucumber-Capybara-Akephalos unit tester"] => {},
              [VmVmware, "JR-EVM-4.0.1.14-2"] => {},
              [VmVmware, "JR-EVM-4.0.1.14-28620-centos"] => {},
              [VmVmware, "JR-EVM-4.0.1.14-28620-redhat"] => {},
              [VmVmware, "JR-EVM-4.0.1.14-3"] => {},
              [VmVmware, "JR-EVM-4.0.1.14-redo"] => {},
              [VmVmware, "JR-EVM-4_0_1_9"] => {},
              [VmVmware, "JR-EVM-9.9-27736-2011-04-01"] => {},
              [VmVmware, "JR-EVM3_3_2_32_svn_memprof"] => {},
              [VmVmware, "JR-EVM_3_3_2_32_svn_memprof_for_comparison"] => {},
              [VmVmware, "JR-EVM_4_0_1_8_svn_memprof"] => {},
              [VmVmware, "JR-Region-5-26665-2011-02-22"] => {},
              [VmVmware, "JR-Region-99-26665-2011-02-22"] => {},
              [VmVmware, "JR-SQL2005"] => {},
              [VmVmware, "JR-SQL2005-CLONE"] => {},
              [VmVmware, "JR-svn-nightly-25707-2010-12-26"] => {}
            },
            [TemplateVmware, "RcuCloneTestTemplate"] => {},
            [TemplateVmware, "XavTmpl"] => {},
            [TemplateVmware, "xyz"] => {},
            [TemplateVmware, "xyz1"] => {},
            [VmVmware, "Dev Cucumber Nightly Appl 2011-05-19"] => {},
            [VmVmware, "DEV-Oleg"] => {},
            [VmVmware, "DEV-RichO"] => {},
            [VmVmware, "Hennessy ReiserFS ubuntu server"] => {},
            [VmVmware, "test3"] => {}
          }
        },
        [EmsFolder, "New Datacenter", {:is_datacenter => true}] => {
          [EmsFolder, "host", {:is_datacenter => false}] => {},
          [EmsFolder, "vm", {:is_datacenter => false}] => {}
        },
        [EmsFolder, "Prod", {:is_datacenter => true}] => {
          [EmsFolder, "host", {:is_datacenter => false}] => {
            [EmsCluster, "Testing-Production Cluster"] => {
              [ResourcePool, "Default for Cluster Testing-Production Cluster", {:is_default => true}] => {
                [ResourcePool, "Citrix", {:is_default => false}] => {
                  [VmVmware, "Citrix 5"] => {}
                },
                [ResourcePool, "Citrix VDI VM's", {:is_default => false}] => {
                  [VmVmware, "Citrix-Mahwah1"] => {},
                  [VmVmware, "Citrix-Mahwah2"] => {}
                },
                [ResourcePool, "Production Test environment", {:is_default => false}] => {
                  [VmVmware, "M-TestDC1"] => {},
                  [VmVmware, "VC41Test"] => {},
                  [VmVmware, "VC41Test-Prod"] => {}
                },
                [ResourcePool, "Testing", {:is_default => false}] => {
                  [ResourcePool, "Brandon", {:is_default => false}] => {
                    [VmVmware, "BD-EVM-4.0.1.15"] => {},
                    [VmVmware, "BD-EVM-Nightly 28939-svn"] => {}
                  },
                  [ResourcePool, "Joe", {:is_default => false}] => {
                    [VmVmware, "JoeF 4.0.1"] => {}
                  },
                  [ResourcePool, "Marianne", {:is_default => false}] => {
                    [VmVmware, "mgf_3_3_2_34"] => {},
                    [VmVmware, "mgf_40115_svn_formigrate"] => {},
                    [VmVmware, "MGF_Branch_332_svn"] => {},
                    [VmVmware, "mgf_branch_40115_svn"] => {},
                    [VmVmware, "mgf_branch_4015_svn"] => {},
                    [VmVmware, "mgf_build_332_31"] => {},
                    [VmVmware, "mgf_build_40116"] => {},
                    [VmVmware, "mgf_build_40116_formigrate"] => {},
                    [VmVmware, "mgf_nightly_trunk_svn"] => {},
                    [VmVmware, "mgf_trunk_nightly_v4"] => {}
                  },
                  [ResourcePool, "Rich", {:is_default => false}] => {
                    [VmVmware, "ESX-TESTVCINTEGRATION"] => {},
                    [VmVmware, "netapp-sim-host1"] => {},
                    [VmVmware, "netapp-sim-host2"] => {},
                    [VmVmware, "netapp-sim-host3"] => {},
                    [VmVmware, "netapp-sim-host4"] => {},
                    [VmVmware, "netapp-sim-host5"] => {},
                    [VmVmware, "netapp-smis-agent1"] => {},
                    [VmVmware, "netapp-smis-agent2"] => {},
                    [VmVmware, "netapp-smis-agent3"] => {},
                    [VmVmware, "NetappDsTest2"] => {},
                    [VmVmware, "NetAppDsTest4"] => {},
                    [VmVmware, "NetAppDsTest5"] => {},
                    [VmVmware, "NetAppDsTest6"] => {},
                    [VmVmware, "NetAppDsTest7"] => {}
                  },
                  [ResourcePool, "Tina", {:is_default => false}] => {
                    [VmVmware, "DEV-TinaF"] => {},
                    [VmVmware, "TF-Appliance 4.0.1.14"] => {}
                  },
                  [ResourcePool, "TomH", {:is_default => false}] => {
                    [VmVmware, "tch-cos64-nightly-26322"] => {},
                    [VmVmware, "tch-cos64_19GB_restore_"] => {},
                    [VmVmware, "tch-cos64-V4_import_tes"] => {}
                  },
                  [ResourcePool, "Xav", {:is_default => false}] => {
                    [VmVmware, "Xav 4014"] => {},
                    [VmVmware, "Xav 4018"] => {},
                    [VmVmware, "Xav Master"] => {},
                    [VmVmware, "Xav RH 40114"] => {},
                    [VmVmware, "Xav RH 4012"] => {},
                    [VmVmware, "xavsmall"] => {},
                    [VmVmware, "XL Trunk svn2"] => {},
                    [VmVmware, "XL V4 svn"] => {}
                  },
                  [VmVmware, "3.3.2.22"] => {}
                },
                [ResourcePool, "Training", {:is_default => false}] => {
                  [VmVmware, "Training Master DB"] => {},
                  [VmVmware, "Training Region 10 UI"] => {},
                  [VmVmware, "Training Region 10 Worker"] => {}
                },
                [ResourcePool, "VMware View VM's", {:is_default => false}] => {
                  [ResourcePool, "Linked Clones", {:is_default => false}] => {
                    [VmVmware, "View Windows 7 Parent x64"] => {}
                  },
                  [VmVmware, "View Broker"] => {}
                },
                [VmVmware, "KPupgrade"] => {},
                [VmVmware, "netapp_video"] => {},
                [VmVmware, "netapp_video1"] => {},
                [VmVmware, "RM-4.0.1.12C"] => {},
                [VmVmware, "Xav COS 40114"] => {}
              }
            },
            [EmsFolder, "Test", {:is_datacenter => false}] => {
              [HostVmwareEsx, "localhost"] => {
                [ResourcePool, "Default for Host localhost", {:is_default => true}] => {}
              }
            }
          },
          [EmsFolder, "vm", {:is_datacenter => false}] => {
            [EmsFolder, "BHelgeson", {:is_datacenter => false}] => {},
            [EmsFolder, "Brandon", {:is_datacenter => false}] => {
              [VmVmware, "BD-EVM-Nightly 28939-svn"] => {}
            },
            [EmsFolder, "Discovered virtual machine", {:is_datacenter => false}] => {
              [VmVmware, "3.3.2.22"] => {},
              [VmVmware, "tch-cos64-nightly-26322"] => {}
            },
            [EmsFolder, "Infra", {:is_datacenter => false}] => {
              [VmVmware, "M-TestDC1"] => {}
            },
            [EmsFolder, "JFitzgerald", {:is_datacenter => false}] => {
              [VmVmware, "JoeF 4.0.1"] => {}
            },
            [EmsFolder, "MFeifer", {:is_datacenter => false}] => {
              [VmVmware, "mgf_3_3_2_34"] => {},
              [VmVmware, "mgf_40115_svn_formigrate"] => {},
              [VmVmware, "MGF_Branch_332_svn"] => {},
              [VmVmware, "mgf_branch_40115_svn"] => {},
              [VmVmware, "mgf_branch_4015_svn"] => {},
              [VmVmware, "mgf_build_332_31"] => {},
              [VmVmware, "mgf_build_40116"] => {},
              [VmVmware, "mgf_build_40116_formigrate"] => {},
              [VmVmware, "mgf_nightly_trunk_svn"] => {},
              [VmVmware, "mgf_trunk_nightly_v4"] => {}
            },
            [EmsFolder, "Rich", {:is_datacenter => false}] => {
              [TemplateVmware, "netapp-sim-host-template"] => {},
              [TemplateVmware, "netapp-smis-agent-template"] => {},
              [VmVmware, "ESX-TESTVCINTEGRATION"] => {},
              [VmVmware, "netapp-sim-host1"] => {},
              [VmVmware, "netapp-sim-host2"] => {},
              [VmVmware, "netapp-sim-host3"] => {},
              [VmVmware, "netapp-sim-host4"] => {},
              [VmVmware, "netapp-sim-host5"] => {},
              [VmVmware, "netapp-smis-agent1"] => {},
              [VmVmware, "netapp-smis-agent2"] => {},
              [VmVmware, "netapp-smis-agent3"] => {},
              [VmVmware, "NetappDsTest2"] => {},
              [VmVmware, "NetAppDsTest4"] => {},
              [VmVmware, "NetAppDsTest5"] => {},
              [VmVmware, "NetAppDsTest6"] => {},
              [VmVmware, "NetAppDsTest7"] => {}
            },
            [EmsFolder, "RMoore", {:is_datacenter => false}] => {
              [VmVmware, "RM-4.0.1.12C"] => {}
            },
            [EmsFolder, "THennessy", {:is_datacenter => false}] => {
              [VmVmware, "tch-cos64_19GB_restore_"] => {},
              [VmVmware, "tch-cos64-V4_import_tes"] => {}
            },
            [EmsFolder, "Training", {:is_datacenter => false}] => {
              [VmVmware, "Training Master DB"] => {},
              [VmVmware, "Training Region 10 UI"] => {},
              [VmVmware, "Training Region 10 Worker"] => {}
            },
            [EmsFolder, "VCs", {:is_datacenter => false}] => {
              [VmVmware, "VC41Test"] => {},
              [VmVmware, "VC41Test-Prod"] => {}
            },
            [EmsFolder, "View Environment", {:is_datacenter => false}] => {
              [VmVmware, "View Broker"] => {},
              [VmVmware, "View Windows 7 Parent x64"] => {}
            },
            [EmsFolder, "Xlecauchois", {:is_datacenter => false}] => {
              [VmVmware, "Xav 4014"] => {},
              [VmVmware, "Xav 4018"] => {},
              [VmVmware, "Xav COS 40114"] => {},
              [VmVmware, "Xav Master"] => {},
              [VmVmware, "Xav RH 40114"] => {},
              [VmVmware, "Xav RH 4012"] => {},
              [VmVmware, "xavsmall"] => {},
              [VmVmware, "XL Trunk svn2"] => {},
              [VmVmware, "XL V4 svn"] => {}
            },
            [TemplateVmware, "Citrix-Win7-Temp"] => {},
            [TemplateVmware, "Win2008Templatex86"] => {},
            [TemplateVmware, "Win2k8Template"] => {},
            [VmVmware, "BD-EVM-4.0.1.15"] => {},
            [VmVmware, "Citrix 5"] => {},
            [VmVmware, "Citrix-Mahwah1"] => {},
            [VmVmware, "Citrix-Mahwah2"] => {},
            [VmVmware, "DEV-TinaF"] => {},
            [VmVmware, "KPupgrade"] => {},
            [VmVmware, "netapp_video"] => {},
            [VmVmware, "netapp_video1"] => {},
            [VmVmware, "TF-Appliance 4.0.1.14"] => {}
          }
        }
      }
    )
  end
end
