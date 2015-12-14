
require "spec_helper"

describe ManageIQ::Providers::Microsoft::InfraManager::Refresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(:miq_region)
    @ems = FactoryGirl.create(:ems_microsoft_with_authentication, :zone => zone,
        :hostname => "scvmm1111.manageiq.com", :ipaddress => "192.168.252.90", :security_protocol => "ssl")
    data_file = File.join(File.dirname(__FILE__), %w(.. .. .. .. .. tools scvmm_data get_inventory_output.yml))

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
    expect(ExtManagementSystem.count).to eq(1)
    expect(EmsFolder.count).to eq(4) # HACK: Folder structure for UI a la VMware
    expect(EmsCluster.count).to eq(1)
    expect(Host.count).to eq(3)
    expect(ResourcePool.count).to eq(0)
    expect(Vm.count).to eq(23)
    expect(VmOrTemplate.count).to eq(28)
    expect(CustomAttribute.count).to eq(0)
    expect(CustomizationSpec.count).to eq(0)
    expect(Disk.count).to eq(23)
    expect(GuestDevice.count).to eq(11)
    expect(Hardware.count).to eq(31)
    expect(Lan.count).to eq(0)
    expect(MiqScsiLun.count).to eq(0)
    expect(MiqScsiTarget.count).to eq(0)
    expect(Network.count).to eq(23)
    expect(OperatingSystem.count).to eq(31)
    expect(Snapshot.count).to eq(9)
    expect(Switch.count).to eq(0)
    expect(SystemService.count).to eq(0)
    expect(Relationship.count).to eq(35)

    expect(MiqQueue.count).to eq(28)
    expect(Storage.count).to eq(6)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :api_version => "2.1.0",
      :uid_ems     => "aa767b2f-7ca4-4a2c-bdb3-d269cbef3f8f"
    )
    expect(@ems.ems_folders.size).to eq(4) # HACK: Folder structure for UI a la VMware
    expect(@ems.ems_clusters.size).to eq(1)
    expect(@ems.resource_pools.size).to eq(0)

    expect(@ems.storages.size).to eq(6)
    expect(@ems.hosts.size).to eq(3)
    expect(@ems.vms_and_templates.size).to eq(28)
    expect(@ems.vms.size).to eq(23)
    expect(@ems.miq_templates.size).to eq(5)
    expect(@ems.customization_specs.size).to eq(0)
  end

  def assert_specific_storage
    @storage = Storage.find_by_name("file://hyperv-h01.manageiq.com/G:/")
    expect(@storage).to have_attributes(
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
    expect(@cluster).to have_attributes(
      :ems_ref => "0be27f13-2a7a-4803-8d12-a460b94fdd71",
      :uid_ems => "0be27f13-2a7a-4803-8d12-a460b94fdd71",
      :name    => "US_East",
    )
  end

  def assert_specific_host
    @host = ManageIQ::Providers::Microsoft::InfraManager::Host.find_by_name("hyperv-h01.manageiq.com")
    expect(@host).to have_attributes(
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

    expect(@host.operating_system).to have_attributes(
      :product_name => "Microsoft Windows Server 2012 R2 Datacenter ",
      :version      => "6.3.9600",
      :product_type => "microsoft"
    )

    expect(@host.hardware).to have_attributes(
      :cpu_speed            => 2394,
      :cpu_type             => "Intel Xeon 179",
      :manufacturer         => "Intel",
      :model                => "Xeon",
      :memory_mb            => 131_059,
      :memory_console       => nil,
      :cpu_sockets          => 2,
      :cpu_total_cores      => 16,
      :cpu_cores_per_socket => 8,
      :guest_os             => nil,
      :guest_os_full_name   => nil,
      #:vmotion_enabled     => true,   # TODO: Add with cluster support
      :cpu_usage            => nil,
      :memory_usage         => nil
    )

    expect(@host.hardware.guest_devices.size).to eq(5)
    expect(@host.hardware.nics.size).to eq(4)
    nic = @host.hardware.nics.find_by_device_name("Ethernet")
    expect(nic).to have_attributes(
      :device_name     => "Ethernet",
      :device_type     => "ethernet",
      :location        => "PCI bus 1, device 0, function 0",
      :present         => true,
      :controller_type => "ethernet"
    )

    @host2 = Host.find_by_name("SFBronagh.manageiq.com")
    expect(@host2.ems_cluster).to eq(@cluster)
  end

  def assert_specific_vm
    v = ManageIQ::Providers::Microsoft::InfraManager::Vm.find_by_name("Salesforce_A")

    expect(v).to have_attributes(
      :template         => false,
      :ems_ref          => "ae9c0f43-295e-4a73-adba-b4cbc7875563",
      :vendor           => "Microsoft",
      :power_state      => "on",
      :location         => "\\ProgramData\\Microsoft\\Windows\\Hyper-V\\Salesforce_A\\Virtual Machines\\194AE824-BA4A-4809-B3BB-86E0ACA1489B.xml",
      :tools_status     => "OS shutdown: true, Time synchronization: true, Data exchange: true, Heartbeat: true, Backup: true",
      :boot_time        => nil,
      :connection_state => "connected",
    )

    expect(v.ext_management_system).to eq(@ems)
    expect(v.host).to eq(@host)

    expect(v.operating_system).to have_attributes(
      :product_name => "64-bit edition of Windows Server 2008 R2 Standard"
    )

    expect(v.custom_attributes.size).to eq(0)
    expect(v.snapshots.size).to eq(1)

    expect(v.hardware).to have_attributes(
      :guest_os           => "64-bit edition of Windows Server 2008 R2 Standard",
      :guest_os_full_name => "64-bit edition of Windows Server 2008 R2 Standard",
      :bios               => "67b7b7ae-34aa-474e-9050-02ed3c633f6c",
      :cpu_total_cores    => 1,
      :annotation         => nil,
      :memory_mb          => 512
    )

    expect(v.hardware.disks.size).to eq(1)
    disk = v.hardware.disks.find_by_device_name("WS2008R2Corex64Ent_F5C854FE-D17D-4AE1-BC32-B55F189D807A")
    expect(disk).to have_attributes(
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
    expect(snapshot).to have_attributes(
      :uid         => "51629E91-8D04-4266-98F5-1DB77E88EE9A",
      :ems_ref     => "51629E91-8D04-4266-98F5-1DB77E88EE9A",
      :parent_uid  => "194AE824-BA4A-4809-B3BB-86E0ACA1489B",
      :name        => "Salesforce_A - (05/05/2014 07:57:13)",
      :description => nil,
    )
    # TODO: Add "Stored" status value in DB. This is a VM that has been provisioned but not deployed

    expect(v.hardware.guest_devices.size).to eq(1)
    dvd = v.hardware.guest_devices.first
    expect(dvd).to have_attributes(
      :device_name     => "rhel-server-6.2-x86_64-boot.iso",
      :device_type     => "cdrom",
      :filename        => "C:\\ProgramData\\Microsoft\\Windows\\Hyper-V\\Salesforce_A\\rhel-server-6.2-x86_64-boot.iso",
      :controller_type => "IDE",
      :present         => true,
      :start_connected => true,
    )

    v = Vm.find_by_name("SCVMM1111")
    expect(v.hardware.networks.size).to eq(1)
    network = v.hardware.networks.first
    expect(network).to have_attributes(
      :hostname  => "SCVMM1111.manageiq.com",
      :ipaddress => "192.168.252.90"
    )

    v = Vm.find_by_name("ERP_A")
    dvd = v.hardware.guest_devices.first
    expect(dvd).to have_attributes(
      :device_name => "ERP_A",
      :filename    => "D:",
    )
  end

  def assert_relationship_tree
    expect(@ems.descendants_arranged).to match_relationship_tree(
      [EmsFolder, "Datacenters", {:is_datacenter => false}] => {
        [EmsFolder, "SCVMM", {:is_datacenter => true}] => {
          [EmsFolder, "host", {:is_datacenter => false}] => {
            [EmsCluster, "US_East"]                                                         => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Host, "hyperv-h01.manageiq.com"] => {},
          },
          [EmsFolder, "vm", {:is_datacenter => false}]   => {
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "testvm1"]                                                            => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "WS2008R2CloTem"]                                                     => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "WS2008R2CoreTem"]                                                    => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "WS2008R2Tem2"]                                                       => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "WS2008R2TemTem"]                                                     => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "bronze_storage_vm1"]                                                       => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "dynamic_vm"]                                                               => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "EastCost_sales"]                                                           => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ERP_A"]                                                                    => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ERP_A1"]                                                                   => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ERP_B"]                                                                    => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ERP_C"]                                                                    => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ERP_D"]                                                                    => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "hostname_test"]                                                            => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "hostname_testing"]                                                         => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "Salesforce_A"]                                                             => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "Salesforce_B"]                                                             => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "SCVMM1111"]                                                                => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ServerCore_tools"]                                                         => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "SQLServer1"]                                                               => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "SQLServer2"]                                                               => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "SQLServer3"]                                                               => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "SQLServer4"]                                                               => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "Storage_vm1"]                                                              => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "tenant_lib_vm"]                                                            => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "WestCoast_Sales"]                                                          => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "WS2008R2Corex64Ent", {:ems_ref => "1f3e7da4-9f67-4e4f-b968-b7d1e2a4aed8"}] => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "WS2008R2Corex64Ent", {:ems_ref => "5e55b0ea-75e2-488e-b834-b6c4e22c67f5"}] => {},
          }
        }
      }
    )
  end
end
