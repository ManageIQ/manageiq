
describe ManageIQ::Providers::Microsoft::InfraManager::Refresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(:miq_region)
    @ems = FactoryGirl.create(:ems_microsoft_with_authentication, :zone => zone,
        :hostname => "scvmm1111.manageiq.com", :ipaddress => "192.168.252.90", :security_protocol => "ssl")

    data_file = Rails.root.join("spec/tools/scvmm_data/get_inventory_output.yml")
    output    = YAML.load_file(data_file)
    allow(ManageIQ::Providers::Microsoft::InfraManager).to receive(:execute_powershell).and_return(output)
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:scvmm)
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
      assert_esx_host
      assert_specific_vm
      assert_specific_guest_devices
      assert_specific_snapshot
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
    expect(Vm.count).to eq(4)
    expect(VmOrTemplate.count).to eq(7)
    expect(CustomAttribute.count).to eq(0)
    expect(CustomizationSpec.count).to eq(0)
    expect(Disk.count).to eq(7)
    expect(GuestDevice.count).to eq(9)
    expect(Hardware.count).to eq(10)
    expect(Lan.count).to eq(2)
    expect(MiqScsiLun.count).to eq(0)
    expect(MiqScsiTarget.count).to eq(0)
    expect(Network.count).to eq(4)
    expect(OperatingSystem.count).to eq(10)
    expect(Snapshot.count).to eq(1)
    expect(Switch.count).to eq(4)
    expect(SystemService.count).to eq(0)
    expect(Relationship.count).to eq(14)
    expect(MiqQueue.count).to eq(7)
    expect(Storage.count).to eq(6)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :api_version => "2.1.0",
      :uid_ems     => "a2b45b8b-ff0e-425c-baf7-24626963a27c"
    )

    expect(@ems.ems_folders.size).to eq(4) # HACK: Folder structure for UI a la VMware
    expect(@ems.ems_clusters.size).to eq(1)
    expect(@ems.resource_pools.size).to eq(0)

    expect(@ems.storages.size).to eq(6)
    expect(@ems.hosts.size).to eq(3)
    expect(@ems.vms_and_templates.size).to eq(7)
    expect(@ems.vms.size).to eq(4)
    expect(@ems.miq_templates.size).to eq(3)
    expect(@ems.customization_specs.size).to eq(0)
  end

  def assert_specific_storage
    storage_name = "file://qeblade33.cfme-qe-vmm-ad.rhq.lab.eng.bos.redhat.com" \
      "/C:/ClusterStorage/CLUSP04%20Prod%20Volume%203-1"

    @storage = Storage.find_by(:name => storage_name)

    expect(@storage).to have_attributes(
      :ems_ref                     => "15fb039d-027a-4113-8504-a37fd0994dca",
      :name                        => storage_name,
      :store_type                  => "CSVFS",
      :total_space                 => 563_757_445_120,
      :free_space                  => 462_748_672_000,
      :multiplehostaccess          => 1,
      :location                    => "15fb039d-027a-4113-8504-a37fd0994dca",
      :thin_provisioning_supported => true
      )
  end

  def assert_specific_cluster
    @cluster = EmsCluster.find_by(:name => "hyperv_cluster")

    expect(@cluster).to have_attributes(
      :ems_ref => "8e830204-6448-4817-b220-34af48ccf8ca",
      :uid_ems => "8e830204-6448-4817-b220-34af48ccf8ca",
      :name    => "hyperv_cluster",
    )
  end

  def assert_specific_host
    hostname = "qeblade33.cfme-qe-vmm-ad.rhq.lab.eng.bos.redhat.com"
    @host = ManageIQ::Providers::Microsoft::InfraManager::Host.find_by(:name => hostname)
    expect(@host).to have_attributes(
      :ems_ref          => "18060bb0-05b9-40fb-b1e3-dfccb8d85c6b",
      :name             => hostname,
      :hostname         => hostname,
      :ipaddress        => "10.16.4.54",
      :vmm_vendor       => "microsoft",
      :vmm_version      => "6.3.9600.17787",
      :vmm_product      => "HyperV",
      :power_state      => "on",
      :connection_state => "connected"
    )

    expect(@host.operating_system).to have_attributes(
      :product_name => "Microsoft Windows Server 2012 R2 Standard ",
      :version      => "6.3.9600",
      :product_type => "microsoft"
    )

    expect(@host.hardware).to have_attributes(
      :cpu_speed            => 2133,
      :cpu_type             => "Intel Xeon 179",
      :manufacturer         => "Intel",
      :model                => "Xeon",
      :memory_mb            => 73_716,
      :memory_console       => nil,
      :cpu_sockets          => 2,
      :cpu_total_cores      => 16,
      :cpu_cores_per_socket => 8,
      :guest_os             => nil,
      :guest_os_full_name   => nil,
      :cpu_usage            => nil,
      :memory_usage         => nil
    )

    expect(@host.hardware.guest_devices.size).to eq(3)
    expect(@host.hardware.nics.size).to eq(3)
    nic = @host.hardware.nics.find_by_device_name("Ethernet")
    expect(nic).to have_attributes(
      :device_name     => "Ethernet",
      :device_type     => "ethernet",
      :location        => "PCI bus 16, device 0, function 0",
      :present         => true,
      :controller_type => "ethernet"
    )

    # @host2 = Host.find_by(:name => "SFBronagh.manageiq.com")
    # expect(@host2.ems_cluster).to eq(@cluster)
  end

  def assert_esx_host
    esx = Host.find_by_vmm_product("VMWareESX")
    expect(esx).to eq(nil)
  end

  def assert_specific_vm
    v = ManageIQ::Providers::Microsoft::InfraManager::Vm.find_by(:name => "WS2008R2Core-JK")

    location = "\\ProgramData\\Microsoft\\Windows\\Hyper-V\\Virtual Machines" \
      "\\6D327596-1341-4072-81F1-2658DB7F073B.xml"

    expect(v).to have_attributes(
      :template         => false,
      :ems_ref          => "14249d0a-0bd8-44cb-9edc-53707f66053f",
      :vendor           => "microsoft",
      :power_state      => "off",
      :location         => location,
      :tools_status     => "OS shutdown: true, Time synchronization: true, Data exchange: true, Heartbeat: true, Backup: true",
      :boot_time        => nil,
      :connection_state => "connected",
    )

    expect(v.ext_management_system).to eq(@ems)
    expect(v.host).to eq(@host)

    expect(v.operating_system).to have_attributes(
      :product_name => "Unknown"
    )

    expect(v.custom_attributes.size).to eq(0)
    expect(v.snapshots.size).to eq(1)

    expect(v.hardware).to have_attributes(
      :guest_os             => "Unknown",
      :guest_os_full_name   => "Unknown",
      :bios                 => "2c67139b-76e1-40fd-896f-407ee9efc447",
      :cpu_total_cores      => 1,
      :cpu_sockets          => 1,
      :cpu_cores_per_socket => 1,
      :annotation           => nil,
      :memory_mb            => 512
    )

    expect(v.hardware.disks.size).to eq(1)
    disk = v.hardware.disks.find_by_device_name("WS2008R2Corex64Ent_5882F22A-B8DF-4D7C-BB30-F4E302D242AA")

    location = "C:\\Users\\Public\\Documents\\Hyper-V\\Virtual hard disks" \
      "\\WS2008R2Corex64Ent_5882F22A-B8DF-4D7C-BB30-F4E302D242AA.avhd"

    expect(disk).to have_attributes(
      :device_name     => "WS2008R2Corex64Ent_5882F22A-B8DF-4D7C-BB30-F4E302D242AA",
      :device_type     => "disk",
      :controller_type => "IDE",
      :present         => true,
      :filename        => location,
      :location        => location,
      :size            => 136_365_211_648,
      :mode            => "persistent",
      :disk_type       => "thin",  # TODO: need to add a differencing disk
      :start_connected => true
    )

    # TODO: Add "Stored" status value in DB. This is a VM that has been provisioned but not deployed
  end

  def assert_specific_snapshot
    v = ManageIQ::Providers::Microsoft::InfraManager::Vm.find_by(:name => "WS2008R2Core-JK")

    expect(v.snapshots.size).to eq(1)
    snapshot = v.snapshots.first

    expect(snapshot).to have_attributes(
      :uid         => "8E6AA643-7EF1-4945-811D-857017D921A1",
      :ems_ref     => "8E6AA643-7EF1-4945-811D-857017D921A1",
      :parent_uid  => "6D327596-1341-4072-81F1-2658DB7F073B",
      :name        => "WS2008R2Core-JK - (2/17/2016 - 2:10:53 PM)",
      :description => nil
    )
  end

  def assert_specific_guest_devices
    v0 = ManageIQ::Providers::Microsoft::InfraManager::Vm.find_by(:name => "CFME-56011-JT")
    v1 = ManageIQ::Providers::Microsoft::InfraManager::Vm.find_by(:name => "jerrykbiker-dnd")
    v2 = ManageIQ::Providers::Microsoft::InfraManager::Vm.find_by(:name => "DualDVDa")

    expect(v0.hardware.guest_devices.size).to eq(0)
    expect(v1.hardware.guest_devices.size).to eq(1)
    expect(v2.hardware.guest_devices.size).to eq(2)

    expect(v0.hardware.guest_devices).to be_empty

    expect(v1.hardware.guest_devices.first).to have_attributes(
      :device_name     => "LinuxAgent",
      :device_type     => "cdrom",
      :filename        => "\\\\cfme_hyperv.cfme-qe-vmm-ad.rhq.lab.eng.bos.redhat.com\\scvmm2\\jerrykbiker-dnd\\LinuxAgent.iso",
      :controller_type => "IDE",
      :present         => true,
      :start_connected => true,
    )

    expect(v2.hardware.guest_devices.order(:device_name).first).to have_attributes(
      :device_name     => "en_office_professional_plus_2016_x005F_x86_x005F_x64_dvd_6962141",
      :device_type     => "cdrom",
      :filename        => "C:\\tmp\\en_office_professional_plus_2016_x005F_x86_x005F_x64_dvd_6962141.iso",
      :controller_type => "IDE",
      :present         => true,
      :start_connected => true,
    )

    expect(v2.hardware.guest_devices.order(:device_name).last).to have_attributes(
      :device_name     => "en_visio_professional_2016_x005F_x86_x005F_x64_dvd_6962139",
      :device_type     => "cdrom",
      :filename        => "C:\\tmp\\en_visio_professional_2016_x005F_x86_x005F_x64_dvd_6962139.iso",
      :controller_type => "IDE",
      :present         => true,
      :start_connected => true,
    )
  end

  def assert_relationship_tree
    expect(@ems.descendants_arranged).to match_relationship_tree(
      [EmsFolder, "Datacenters", {:hidden => true}] => {
        [Datacenter, "SCVMM"] => {
          [EmsFolder, "host", {:hidden => true}] => {
            [EmsCluster, "hyperv_cluster"]                                                     => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Host, "dhcp129-212.brq.redhat.com"] => {},
          },
          [EmsFolder, "vm", {:hidden => true}]   => {
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-54402-12011420"] => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-hyperv-5.5.0.13-2.x86_64"] => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-hyperv-5.5.3.4-1.x86_64"]  => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "CFME-56011-JT"]                       => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "DualDVDa"]                            => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "WS2008R2Core-JK"]                     => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "jerrykbiker-dnd"]                     => {},
          }
        }
      }
    )
  end
end
