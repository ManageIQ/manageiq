
describe ManageIQ::Providers::Microsoft::InfraManager::Refresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(:miq_region)
    @ems = FactoryGirl.create(:ems_microsoft_with_authentication, :zone => zone,
        :hostname => "scvmm1111.manageiq.com", :ipaddress => "192.168.252.90", :security_protocol => "ssl")

    data_file = Rails.root.join("spec", "tools", "scvmm_data", "get_inventory_output.json")
    output    = JSON.parse(IO.read(data_file.to_s))
    allow(ManageIQ::Providers::Microsoft::InfraManager).to receive(:execute_powershell_json).and_return(output)
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
    expect(Vm.count).to eq(46)
    expect(VmOrTemplate.count).to eq(71)
    expect(CustomAttribute.count).to eq(0)
    expect(CustomizationSpec.count).to eq(0)
    expect(Disk.count).to eq(66)
    expect(GuestDevice.count).to eq(13)
    expect(Hardware.count).to eq(74)
    expect(Lan.count).to eq(6)
    expect(MiqScsiLun.count).to eq(0)
    expect(MiqScsiTarget.count).to eq(0)
    expect(Network.count).to eq(46)
    expect(OperatingSystem.count).to eq(74)
    expect(Snapshot.count).to eq(10)
    expect(Switch.count).to eq(4)
    expect(SystemService.count).to eq(0)
    expect(Relationship.count).to eq(78)
    expect(MiqQueue.count).to eq(71)
    expect(Storage.count).to eq(14)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :api_version => "2.1.0",
      :uid_ems     => "a2b45b8b-ff0e-425c-baf7-24626963a27c"
    )

    expect(@ems.ems_folders.size).to eq(4) # HACK: Folder structure for UI a la VMware
    expect(@ems.ems_clusters.size).to eq(1)
    expect(@ems.resource_pools.size).to eq(0)

    expect(@ems.storages.size).to eq(13)
    expect(@ems.hosts.size).to eq(3)
    expect(@ems.vms_and_templates.size).to eq(71)
    expect(@ems.vms.size).to eq(46)
    expect(@ems.miq_templates.size).to eq(25)
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
      :total_space                 => 805_333_626_880,
      :free_space                  => 704_289_169_408,
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
      :vmm_version      => "6.3.9600.18623",
      :vmm_product      => "HyperV",
      :power_state      => "on",
      :connection_state => "connected",
      :maintenance      => false,
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

    expect(@host.hardware.guest_devices.size).to eq(2)
    expect(@host.hardware.nics.size).to eq(2)
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
    v = ManageIQ::Providers::Microsoft::InfraManager::Vm.find_by(:name => "WS2008R2Core")

    location = "\\WS2008R2Core\\Virtual Machines\\F36C31F0-A138-4F24-8F56-10A3BFBD7D14.xml"

    expect(v).to have_attributes(
      :template         => false,
      :ems_ref          => "f9d6d611-d835-4f95-ae3d-152eb43652f1",
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
    disk = v.hardware.disks.find_by_device_name("WS2008R2Corex64Ent_C02F48D6-ED11-4F67-B77C-B9EC821A4A3E")

    location = "C:\\WS2008R2Core\\WS2008R2Corex64Ent_C02F48D6-ED11-4F67-B77C-B9EC821A4A3E.avhd"

    expect(disk).to have_attributes(
      :device_name     => "WS2008R2Corex64Ent_C02F48D6-ED11-4F67-B77C-B9EC821A4A3E",
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
    v = ManageIQ::Providers::Microsoft::InfraManager::Vm.find_by(:name => "WS2008R2Core")

    expect(v.snapshots.size).to eq(1)
    snapshot = v.snapshots.first

    expect(snapshot).to have_attributes(
      :uid         => "16FF0C08-04D3-4BEE-9E74-34393E087F4A",
      :ems_ref     => "16FF0C08-04D3-4BEE-9E74-34393E087F4A",
      :parent_uid  => "F36C31F0-A138-4F24-8F56-10A3BFBD7D14",
      :name        => "WS2008R2Core - (6/10/2016 - 8:41:12 AM)",
      :description => nil
    )
  end

  def assert_specific_guest_devices
    v0 = ManageIQ::Providers::Microsoft::InfraManager::Vm.find_by(:name => "fedora-tmpl-sm")
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
      :device_name     => "en_office_professional_plus_2016_x86_x64_dvd_6962141",
      :device_type     => "cdrom",
      :filename        => "C:\\tmp\\en_office_professional_plus_2016_x86_x64_dvd_6962141.iso",
      :controller_type => "IDE",
      :present         => true,
      :start_connected => true,
    )

    expect(v2.hardware.guest_devices.order(:device_name).last).to have_attributes(
      :device_name     => "en_visio_professional_2016_x86_x64_dvd_6962139",
      :device_type     => "cdrom",
      :filename        => "C:\\tmp\\en_visio_professional_2016_x86_x64_dvd_6962139.iso",
      :controller_type => "IDE",
      :present         => true,
      :start_connected => true,
    )
  end

  def assert_relationship_tree
    expect(@ems.descendants_arranged).to match_relationship_tree(
      [EmsFolder, "Datacenters"] => {
        [Datacenter, "SCVMM"] => {
          [EmsFolder, "host"] => {
            [EmsCluster, "hyperv_cluster"]                                                     => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Host, "dhcp129-212.brq.redhat.com"] => {},
          },
          [EmsFolder, "vm"] => {
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "WS12CoreTemplateHA"]                   => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "Win12SCoreTemplate"]                   => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "Win7SmallTemplate"]                    => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-56402-02272311"]                  => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-57017-12192116"]                  => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-57103-0221213"]                   => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-57200-03221429"]                  => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-57201-04062043"]                  => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-5721"]                            => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-58015-0517195"]                   => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-58016-05221701"]                  => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-58016-05221944"]                  => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-58017-05252117"]                  => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-nightly-58015-201705180216"]      => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "fedora-sm-tmpl"]                       => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "fedora-sm-tmpl-ha"]                    => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "miq-nightly-201705232000"]             => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "miq-nightly-201705280915"]             => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "miq-stable-euwe-3-20170413"]           => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "miq-stable-fine-1-20170510"]           => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "miq-stable-fine-2-20170531"]           => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "win7pro64 base"]                       => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "win81npro64-base"]                     => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "ws2008r2d-sp1-tpl"]                    => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Template, "ws2008s-sp2-tpl"]                      => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "CFME-5554-JT"]                               => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "CFME-56400-JT"]                              => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "CFME-56402-JT"]                              => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "CFME-57100-JT"]                              => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "CFME-57103-JT"]                              => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "CFME-57201-JT"]                              => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "CFME-58014-JT"]                              => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "DualDVDa"]                                   => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "Engineering - win10ent64"]                   => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "Local33SSATest"]                             => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "MoVM"]                                       => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "NoDriveLetter7"]                             => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "REFS16Test3"]                                => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ReFS2016Test2"]                              => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "Ubu1404LTS"]                                 => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "WS2008R2Core"]                               => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "WS2016NTFS"]                                 => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "Win7SmallTmpl"]                              => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-vmm-ad-bu-DND"]                         => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-vmm-ad-pri-DND"]                        => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cluster-storage"]                            => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "dajo-dsl"]                                   => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "django-win7-jt"]                             => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "fedora-small"]                               => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "fedora-tmpl-sm"]                             => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "jerrykbiker-dnd"]                            => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "jt_dnd_w12r2d_dev"]                          => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "jt_dnd_w12r2d_scvmm_dev"]                    => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "lkhomenk-fedora-tmpl-sm"]                    => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "scvmm-sp1"]                                  => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "scvmm-sp1-1"]                                => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "scvmm2"]                                     => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "shveta_miq_0515"]                            => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "smis_netapp_dnd"]                            => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "sshveta_58013"]                              => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "test-provt-6il0"]                            => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "test-scat-24xc0001"]                         => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "test-scat-dq120001"]                         => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "test-scat-g9oa0001"]                         => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "test-scat-gzqc0001"]                         => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "test-scat-imtb0001"]                         => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "test-scat-mspj0001"]                         => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "test-scat-rsc90001"]                         => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "test-scat-zxiq0001"]                         => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ws12r2dc-2DVDs"]                             => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ws2008r2d-sp1-26"]                           => {},
          }
        }
      }
    )
  end
end
