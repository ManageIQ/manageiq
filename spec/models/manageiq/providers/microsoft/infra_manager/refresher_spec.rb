
describe ManageIQ::Providers::Microsoft::InfraManager::Refresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(:miq_region)
    @ems = FactoryGirl.create(:ems_microsoft_with_authentication, :zone => zone,
        :hostname => "scvmm1111.manageiq.com", :ipaddress => "192.168.252.90", :security_protocol => "ssl")

    data_file = File.join(File.dirname(__FILE__), %w(.. .. .. .. .. tools scvmm_data get_inventory_output.yml))
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
      # assert_specific_cluster
      assert_specific_host
      assert_specific_vm
      assert_specific_storage
      assert_relationship_tree
    end
  end

  def assert_table_counts
    expect(ExtManagementSystem.count).to eq(1)
    expect(EmsFolder.count).to eq(4) # HACK: Folder structure for UI a la VMware
    expect(EmsCluster.count).to eq(0)
    expect(Host.count).to eq(2)
    expect(ResourcePool.count).to eq(0)
    expect(Vm.count).to eq(2)
    expect(VmOrTemplate.count).to eq(3)
    expect(CustomAttribute.count).to eq(0)
    expect(CustomizationSpec.count).to eq(0)
    expect(Disk.count).to eq(3)
    expect(GuestDevice.count).to eq(14)
    expect(Hardware.count).to eq(5)
    expect(Lan.count).to eq(2)
    expect(MiqScsiLun.count).to eq(0)
    expect(MiqScsiTarget.count).to eq(0)
    expect(Network.count).to eq(2)
    expect(OperatingSystem.count).to eq(5)
    expect(Snapshot.count).to eq(1)
    expect(Switch.count).to eq(2)
    expect(SystemService.count).to eq(0)
    expect(Relationship.count).to eq(10)
    expect(MiqQueue.count).to eq(3)
    expect(Storage.count).to eq(2)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :api_version => "2.1.0",
      :uid_ems     => "dce10b7e-f8e5-4c56-974e-83099c3000fb"
    )

    expect(@ems.ems_folders.size).to eq(4) # HACK: Folder structure for UI a la VMware
    expect(@ems.ems_clusters.size).to eq(0)
    expect(@ems.resource_pools.size).to eq(0)

    expect(@ems.storages.size).to eq(2)
    expect(@ems.hosts.size).to eq(2)
    expect(@ems.vms_and_templates.size).to eq(3)
    expect(@ems.vms.size).to eq(2)
    expect(@ems.miq_templates.size).to eq(1)
    expect(@ems.customization_specs.size).to eq(0)
  end

  def assert_specific_storage
    storage_name = "file://dell-r410-01.cloudformswin.lab.redhat.com/C:/"
    @storage = Storage.find_by_name(storage_name)
    expect(@storage).to have_attributes(
      :ems_ref                     => "1c00651a-ca2a-4676-976b-55875305a89f",
      :name                        => storage_name,
      :store_type                  => nil,
      :total_space                 => 499_738_734_592,
      :free_space                  => 467_535_630_336,
      :multiplehostaccess          => 1,
      :location                    => "1c00651a-ca2a-4676-976b-55875305a89f",
      :thin_provisioning_supported => true
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
    hostname = "dell-r410-03.cloudformswin.lab.redhat.com"
    @host = ManageIQ::Providers::Microsoft::InfraManager::Host.find_by_name(hostname)
    expect(@host).to have_attributes(
      :ems_ref          => "6a2c5120-2931-4cc2-a445-8d28dfc73e03",
      :name             => hostname,
      :hostname         => hostname,
      :ipaddress        => "10.8.96.25",
      :vmm_vendor       => "microsoft",
      :vmm_version      => "6.3.9600.17787",
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
      :cpu_usage            => nil,
      :memory_usage         => nil
    )

    expect(@host.hardware.guest_devices.size).to eq(6)
    expect(@host.hardware.nics.size).to eq(4)
    nic = @host.hardware.nics.find_by_device_name("Ethernet")
    expect(nic).to have_attributes(
      :device_name     => "Ethernet",
      :device_type     => "ethernet",
      :location        => "PCI bus 3, device 0, function 0",
      :present         => true,
      :controller_type => "ethernet"
    )

    # @host2 = Host.find_by_name("SFBronagh.manageiq.com")
    # expect(@host2.ems_cluster).to eq(@cluster)
  end

  def assert_specific_vm
    v = ManageIQ::Providers::Microsoft::InfraManager::Vm.find_by_name("linux2")

    expect(v).to have_attributes(
      :template         => false,
      :ems_ref          => "c4425913-7043-4d2a-a229-75f051a8127b",
      :vendor           => "Microsoft",
      :power_state      => "on",
      :location         => "\\ProgramData\\Microsoft\\Windows\\Hyper-V\\linux2\\Virtual Machines\\95412AD4-2CBF-4FAF-AE4B-0C56C30D1B84.xml",
      :tools_status     => "OS shutdown: true, Time synchronization: true, Data exchange: true, Heartbeat: true, Backup: true",
      :boot_time        => nil,
      :connection_state => "connected",
    )

    expect(v.ext_management_system).to eq(@ems)
    expect(v.host).to eq(@host)

    expect(v.operating_system).to have_attributes(
      :product_name => "Red Hat Enterprise Linux 7 (64 bit)"
    )

    expect(v.custom_attributes.size).to eq(0)
    expect(v.snapshots.size).to eq(1)

    expect(v.hardware).to have_attributes(
      :guest_os           => "Red Hat Enterprise Linux 7 (64 bit)",
      :guest_os_full_name => "Red Hat Enterprise Linux 7 (64 bit)",
      :bios               => "a3bd95a2-dd8d-4242-bd57-02621c4eb153",
      :cpu_total_cores    => 1,
      :annotation         => nil,
      :memory_mb          => 512
    )

    expect(v.hardware.disks.size).to eq(1)
    disk = v.hardware.disks.find_by_device_name("Blank Disk - Small_77376D2F-3967-476A-942A-6314A3337EEC")
    expect(disk).to have_attributes(
      :device_name     => "Blank Disk - Small_77376D2F-3967-476A-942A-6314A3337EEC",
      :device_type     => "disk",
      :controller_type => "IDE",
      :present         => true,
      :filename        => "C:\\ProgramData\\Microsoft\\Windows\\Hyper-V\\linux2\\Blank Disk - Small_77376D2F-3967-476A-942A-6314A3337EEC.avhd",
      :location        => "C:\\ProgramData\\Microsoft\\Windows\\Hyper-V\\linux2\\Blank Disk - Small_77376D2F-3967-476A-942A-6314A3337EEC.avhd",
      :size            => 16.gigabytes,
      :mode            => "persistent",
      :disk_type       => "thin",  # TODO: need to add a differencing disk
      :start_connected => true
    )

    expect(v.snapshots.size).to eq(1)
    snapshot = v.snapshots.find_by_name("linux2 - (02/23/2016 10:35:23)")
    expect(snapshot).to have_attributes(
      :uid         => "406845EA-0CF6-44CD-9D96-24A157DF5736",
      :ems_ref     => "406845EA-0CF6-44CD-9D96-24A157DF5736",
      :parent_uid  => "95412AD4-2CBF-4FAF-AE4B-0C56C30D1B84",
      :name        => "linux2 - (02/23/2016 10:35:23)",
      :description => nil,
    )
    # TODO: Add "Stored" status value in DB. This is a VM that has been provisioned but not deployed

    expect(v.hardware.guest_devices.size).to eq(1)
    dvd = v.hardware.guest_devices.first
    expect(dvd).to have_attributes(
      :device_name     => "CentOS-7-x86_64-Minimal-1511.iso",
      :device_type     => "cdrom",
      :filename        => "C:\\ProgramData\\Microsoft\\Windows\\Hyper-V\\linux2\\CentOS-7-x86_64-Minimal-1511.iso",
      :controller_type => "IDE",
      :present         => true,
      :start_connected => true,
    )

    # v = Vm.find_by_name("linux2")
    # expect(v.hardware.networks.size).to eq(1)
    # network = v.hardware.networks.first
    # puts "Network #{network.inspect}"
    # expect(network).to have_attributes(
    #   :hostname  => "SCVMM1111.manageiq.com",
    #   :ipaddress => "192.168.252.90"
    # )

    v = Vm.find_by_name("vm_linux1")
    dvd = v.hardware.guest_devices.first
    expect(dvd).to have_attributes(
      :device_name => "vm_linux1",
      :filename    => "F:",
    )
  end

  def assert_relationship_tree
    expect(@ems.descendants_arranged).to match_relationship_tree(
      [EmsFolder, "Datacenters", {:is_datacenter => false}] => {
        [EmsFolder, "SCVMM", {:is_datacenter => true}] => {
          [EmsFolder, "host", {:is_datacenter => false}] => {
            [ManageIQ::Providers::Microsoft::InfraManager::Host, "dell-r410-01.cloudformswin.lab.redhat.com"] => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Host, "dell-r410-03.cloudformswin.lab.redhat.com"] => {},
          },
          [EmsFolder, "vm", {:is_datacenter => false}]   => {
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "linux_template"] => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "linux2"]    => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "vm_linux1"] => {},
          }
        }
      }
    )
  end
end
