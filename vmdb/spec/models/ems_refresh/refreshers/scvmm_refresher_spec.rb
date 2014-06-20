
require "spec_helper"

describe EmsRefresh::Refreshers::ScvmmRefresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_microsoft_with_authentication, :zone => zone,
        :hostname => "scvmm1111.manageiq.com", :ipaddress => "192.168.252.90")
    data_file = File.join(File.dirname(__FILE__), %w{.. .. .. tools scvmm_data get_inventory_output.yml})

    # See HACK comment in EmsMicrosoft.raw_connect for details around suppressing
    # the benign GSSAPI warnings printed when the winrm gem is required.
    # These warnings are also printed when the webmock gem
    # is required by rspec since it also depends on the GSSAPI gem too.
    require 'winrm'

    WinRM::WinRMWebService.any_instance.stub(:run_powershell_script => YAML.load_file(data_file))
  end

  it "will perform a full refresh" do
    2.times do  # Run twice to verify that a second run with existing data does not change anything
      @ems.reload

      EmsRefresh.refresh(@ems)
      @ems.reload

      assert_table_counts
      assert_ems
      assert_specific_cluster
      assert_specific_host
      assert_specific_vm
      assert_specific_storage
      assert_relationship_tree
    end
  end

  def assert_table_counts
    ExtManagementSystem.count.should == 1
    EmsFolder.count.should           == 4 # HACK: Folder structure for UI a la VMware
    EmsCluster.count.should          == 1
    Host.count.should                == 3
    ResourcePool.count.should        == 0
    Vm.count.should                  == 23
    VmOrTemplate.count.should        == 28
    CustomAttribute.count.should     == 0
    CustomizationSpec.count.should   == 0
    Disk.count.should                == 23
    GuestDevice.count.should         == 11
    Hardware.count.should            == 31
    Lan.count.should                 == 0
    MiqScsiLun.count.should          == 0
    MiqScsiTarget.count.should       == 0
    Network.count.should             == 23
    OperatingSystem.count.should     == 31
    Snapshot.count.should            == 9
    Switch.count.should              == 0
    SystemService.count.should       == 0
    Relationship.count.should        == 34

    MiqQueue.count.should            == 28
    Storage.count.should             == 6
  end

  def assert_ems
    @ems.should have_attributes(
      :api_version => "2.1.0",
      :uid_ems     => "aa767b2f-7ca4-4a2c-bdb3-d269cbef3f8f"
    )
    @ems.ems_folders.size.should         == 4 # HACK: Folder structure for UI a la VMware
    @ems.ems_clusters.size.should        == 1
    @ems.resource_pools.size.should      == 0

    @ems.storages.size.should            == 6
    @ems.hosts.size.should               == 3
    @ems.vms_and_templates.size.should   == 28
    @ems.vms.size.should                 == 23
    @ems.miq_templates.size.should       == 5
    @ems.customization_specs.size.should == 0
  end

  def assert_specific_storage
    @storage = Storage.find_by_name("file://hyperv-h01.manageiq.com/G:/")
    @storage.should have_attributes(
      :ems_ref                     => "afc847e1-9d85-4488-91bb-4284c9a29d07",
      :name                        => "file://hyperv-h01.manageiq.com/G:/",
      :store_type                  => "NTFS",
      :total_space                 => 10_735_316_992,
      :free_space                  => 7_471_022_080,
      :multiplehostaccess          => 1,
      :location                    => "afc847e1-9d85-4488-91bb-4284c9a29d07",
      :thin_provisioning_supported => true,
      # :raw_disk_mappings_supported   => true
      )
  end

  def assert_specific_cluster
    @cluster = EmsCluster.find_by_name("US_East")
    @cluster.should have_attributes(
      :ems_ref => "0be27f13-2a7a-4803-8d12-a460b94fdd71",
      :uid_ems => "0be27f13-2a7a-4803-8d12-a460b94fdd71",
      :name    => "US_East",
    )
  end

  def assert_specific_host
    @host = Host.find_by_name("hyperv-h01.manageiq.com")
    @host.should have_attributes(
      :ems_ref          => "60e92646-b9f8-432a-a71a-5bc169ceeca2",
      :name             => "hyperv-h01.manageiq.com",
      :hostname         => "hyperv-h01.manageiq.com",
      :ipaddress        => "192.168.252.99",
      :vmm_vendor       => "Microsoft",
      :vmm_version      => "6.3.9600.17039",
      :vmm_product      => "HyperV",
      :power_state      => "on",
      :connection_state => "connected"
    )

    @host.operating_system.should have_attributes(
      :product_name => "Microsoft Windows Server 2012 R2 Datacenter ",
      :version      => "6.3.9600",
      :product_type => "microsoft"
    )

    @host.hardware.should have_attributes(
      :cpu_speed          => 2394,
      :cpu_type           => "Intel Xeon 179",
      :manufacturer       => "Intel",
      :model              => "Xeon",
      :memory_cpu         => 131_059,  # MB
      :memory_console     => nil,
      :numvcpus           => 2,
      :logical_cpus       => 16,
      :cores_per_socket   => 8,
      :guest_os           => nil,
      :guest_os_full_name => nil,
      #:vmotion_enabled    => true,   # TODO: Add with cluster support
      :cpu_usage          => nil,
      :memory_usage       => nil
    )

    @host.hardware.guest_devices.size.should == 5
    @host.hardware.nics.size.should == 4
    nic = @host.hardware.nics.find_by_device_name("Ethernet")
    nic.should have_attributes(
      :device_name     => "Ethernet",
      :device_type     => "ethernet",
      :location        => "PCI bus 1, device 0, function 0",
      :present         => true,
      :controller_type => "ethernet"
    )

    @host2 = Host.find_by_name("SFBronagh.manageiq.com")
    @host2.ems_cluster.should == @cluster
  end

  def assert_specific_vm
    v = Vm.find_by_name("Salesforce_A")

    v.should have_attributes(
      :template         => false,
      :ems_ref          => "ae9c0f43-295e-4a73-adba-b4cbc7875563",
      :vendor           => "Microsoft",
      :power_state      => "on",
      :location         => "\\ProgramData\\Microsoft\\Windows\\Hyper-V\\Salesforce_A\\Virtual Machines\\194AE824-BA4A-4809-B3BB-86E0ACA1489B.xml",
      :tools_status     => "OS shutdown: true, Time synchronization: true, Data exchange: true, Heartbeat: true, Backup: true",
      :boot_time        => nil,
      :connection_state => "connected",
    )

    v.ext_management_system.should == @ems
    v.host.should                  == @host

    v.operating_system.should have_attributes(
      :product_name => "64-bit edition of Windows Server 2008 R2 Standard"
    )

    v.custom_attributes.size.should == 0
    v.snapshots.size.should         == 1

    v.hardware.should have_attributes(
      :guest_os           => "64-bit edition of Windows Server 2008 R2 Standard",
      :guest_os_full_name => "64-bit edition of Windows Server 2008 R2 Standard",
      :bios               => "67b7b7ae-34aa-474e-9050-02ed3c633f6c",
      :numvcpus           => 1,
      :annotation         => nil,
      :memory_cpu         => 512   # MB
    )

    v.hardware.disks.size.should == 1
    disk = v.hardware.disks.find_by_device_name("WS2008R2Corex64Ent_F5C854FE-D17D-4AE1-BC32-B55F189D807A")
    disk.should have_attributes(
      :device_name     => "WS2008R2Corex64Ent_F5C854FE-D17D-4AE1-BC32-B55F189D807A",
      :device_type     => "disk",
      :controller_type => "IDE",
      :present         => true,
      :filename        => "C:\\ProgramData\\Microsoft\\Windows\\Hyper-V\\Salesforce_A\\WS2008R2Corex64Ent_F5C854FE-D17D-4AE1-BC32-B55F189D807A.avhd",
      :location        => "C:\\ProgramData\\Microsoft\\Windows\\Hyper-V\\Salesforce_A\\WS2008R2Corex64Ent_F5C854FE-D17D-4AE1-BC32-B55F189D807A.avhd",
      :size            => 127.gigabytes,
      :mode            => "persistent",
      :disk_type       => "thin",  # TODO: need to add a differencing disk
      :start_connected => true
    )

    v.snapshots.size == 1
    snapshot = v.snapshots.find_by_name("Salesforce_A - (05/05/2014 07:57:13)")
    snapshot.should have_attributes(
      :uid         => "51629E91-8D04-4266-98F5-1DB77E88EE9A",
      :ems_ref     => "51629E91-8D04-4266-98F5-1DB77E88EE9A",
      :parent_uid  => "194AE824-BA4A-4809-B3BB-86E0ACA1489B",
      :name        => "Salesforce_A - (05/05/2014 07:57:13)",
      :description => nil,
    )
    # TODO: Add "Stored" status value in DB. This is a VM that has been provisioned but not deployed

    v.hardware.guest_devices.size.should == 1
    dvd = v.hardware.guest_devices.first
    dvd.should have_attributes(
      :device_name     => "rhel-server-6.2-x86_64-boot.iso",
      :device_type     => "cdrom",
      :filename        => "C:\\ProgramData\\Microsoft\\Windows\\Hyper-V\\Salesforce_A\\rhel-server-6.2-x86_64-boot.iso",
      :controller_type => "IDE",
      :present         => true,
      :start_connected => true,
    )

    v = Vm.find_by_name("SCVMM1111")
    v.hardware.networks.size.should == 1
    network = v.hardware.networks.first
    network.should have_attributes(
      :hostname  => "SCVMM1111.manageiq.com",
      :ipaddress => "192.168.252.90"
    )

    v = Vm.find_by_name("ERP_A")
    dvd = v.hardware.guest_devices.first
    dvd.should have_attributes(
      :device_name => "ERP_A",
      :filename    => "D:",
    )
  end

  def assert_relationship_tree
    @ems.descendants_arranged.should match_relationship_tree(
      [EmsFolder, "Datacenters", {:is_datacenter => false}] => {
        [EmsFolder, "SCVMM", {:is_datacenter => true}] => {
          [EmsFolder, "host", {:is_datacenter => false}] => {
            [EmsCluster, "US_East"] => {}
          },
          [EmsFolder, "vm", {:is_datacenter => false}]   => {
            [TemplateMicrosoft, "testvm1"]                                                            => {},
            [TemplateMicrosoft, "WS2008R2CloTem"]                                                     => {},
            [TemplateMicrosoft, "WS2008R2CoreTem"]                                                    => {},
            [TemplateMicrosoft, "WS2008R2Tem2"]                                                       => {},
            [TemplateMicrosoft, "WS2008R2TemTem"]                                                     => {},
            [VmMicrosoft, "bronze_storage_vm1"]                                                       => {},
            [VmMicrosoft, "dynamic_vm"]                                                               => {},
            [VmMicrosoft, "EastCost_sales"]                                                           => {},
            [VmMicrosoft, "ERP_A"]                                                                    => {},
            [VmMicrosoft, "ERP_A1"]                                                                   => {},
            [VmMicrosoft, "ERP_B"]                                                                    => {},
            [VmMicrosoft, "ERP_C"]                                                                    => {},
            [VmMicrosoft, "ERP_D"]                                                                    => {},
            [VmMicrosoft, "hostname_test"]                                                            => {},
            [VmMicrosoft, "hostname_testing"]                                                         => {},
            [VmMicrosoft, "Salesforce_A"]                                                             => {},
            [VmMicrosoft, "Salesforce_B"]                                                             => {},
            [VmMicrosoft, "SCVMM1111"]                                                                => {},
            [VmMicrosoft, "ServerCore_tools"]                                                         => {},
            [VmMicrosoft, "SQLServer1"]                                                               => {},
            [VmMicrosoft, "SQLServer2"]                                                               => {},
            [VmMicrosoft, "SQLServer3"]                                                               => {},
            [VmMicrosoft, "SQLServer4"]                                                               => {},
            [VmMicrosoft, "Storage_vm1"]                                                              => {},
            [VmMicrosoft, "tenant_lib_vm"]                                                            => {},
            [VmMicrosoft, "WestCoast_Sales"]                                                          => {},
            [VmMicrosoft, "WS2008R2Corex64Ent", {:ems_ref => "1f3e7da4-9f67-4e4f-b968-b7d1e2a4aed8"}] => {},
            [VmMicrosoft, "WS2008R2Corex64Ent", {:ems_ref => "5e55b0ea-75e2-488e-b834-b6c4e22c67f5"}] => {},
          }
        }
      }
    )
  end
end
