
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
    ExtManagementSystem.count.should == 1
    EmsFolder.count.should == 4 # HACK: Folder structure for UI a la VMware
    EmsCluster.count.should == 1
    Host.count.should == 3
    ResourcePool.count.should == 0
    Vm.count.should == 75
    VmOrTemplate.count.should == 93
    CustomAttribute.count.should == 0
    CustomizationSpec.count.should == 0
    Disk.count.should == 77
    GuestDevice.count.should == 13
    Hardware.count.should == 96
    Lan.count.should == 4
    MiqScsiLun.count.should == 0
    MiqScsiTarget.count.should == 0
    Network.count.should == 75
    OperatingSystem.count.should == 96
    Snapshot.count.should == 14
    Switch.count.should == 4
    SystemService.count.should == 0
    Relationship.count.should == 100

    MiqQueue.count.should == 93
    Storage.count.should == 6
  end

  def assert_ems
    @ems.should have_attributes(
      :api_version => "2.1.0",
      :uid_ems     => "a2b45b8b-ff0e-425c-baf7-24626963a27c"
    )
    @ems.ems_folders.size.should.should eq(4) # HACK: Folder structure for UI a la VMware
    @ems.ems_clusters.size.should eq(1)
    @ems.resource_pools.size.should eq(0)

    @ems.storages.size.should eq(6)
    @ems.hosts.size.should eq(3)
    @ems.vms_and_templates.size.should eq(93)
    @ems.vms.size.should eq(75)
    @ems.miq_templates.size.should eq(18)
    @ems.customization_specs.size.should eq(0)
  end

  def assert_specific_storage
    @storage = Storage.find_by_name("file://qeblade26.cfme-qe-vmm-ad.rhq.lab.eng.bos.redhat.com/C:/")
    @storage.should have_attributes(
      :ems_ref                     => "66f2c186-a614-40f6-8aff-566f40c43e2c",
      :name                        => "file://qeblade26.cfme-qe-vmm-ad.rhq.lab.eng.bos.redhat.com/C:/",
      :store_type                  => "NTFS",
      :total_space                 => 997_629_882_368,
      :free_space                  => 410_627_387_392,
      :multiplehostaccess          => 1,
      :location                    => "66f2c186-a614-40f6-8aff-566f40c43e2c",
      :thin_provisioning_supported => true,
    # :raw_disk_mappings_supported   => true
    )
  end

  def assert_specific_cluster
    @cluster = EmsCluster.find_by_name("hyperv_clus")
    @cluster.should have_attributes(
      :ems_ref => "e2e79a9e-1d74-4cf4-a77c-956d0dc55f25",
      :uid_ems => "e2e79a9e-1d74-4cf4-a77c-956d0dc55f25",
      :name    => "hyperv_clus",
    )
  end

  def assert_specific_host
    @host = ManageIQ::Providers::Microsoft::InfraManager::Host.find_by_name(
      "qeblade33.cfme-qe-vmm-ad.rhq.lab.eng.bos.redhat.com"
    )
    @host.should have_attributes(
      :ems_ref          => "fc600ded-e7fe-400c-891a-72c57e0f2b3a",
      :name             => "qeblade33.cfme-qe-vmm-ad.rhq.lab.eng.bos.redhat.com",
      :hostname         => "qeblade33.cfme-qe-vmm-ad.rhq.lab.eng.bos.redhat.com",
      :ipaddress        => "10.16.4.54",
      :vmm_vendor       => "Microsoft",
      :vmm_version      => "6.3.9600.17031",
      :vmm_product      => "HyperV",
      :power_state      => "on",
      :connection_state => "connected"
    )

    @host.operating_system.should have_attributes(
      :product_name => "Microsoft Windows Server 2012 R2 Standard ",
      :version      => "6.3.9600",
      :product_type => "microsoft"
    )
    @host.hardware.should have_attributes(
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
      #:vmotion_enabled     => true,   # TODO: Add with cluster support
      :cpu_usage            => nil,
      :memory_usage         => nil
    )
    @host.hardware.guest_devices.size.should eq(3)
    @host.hardware.nics.size.should eq(3)
    nic = @host.hardware.nics.find_by_device_name("Ethernet")
    nic.should have_attributes(
      :device_name     => "Ethernet",
      :device_type     => "ethernet",
      :location        => "PCI bus 16, device 0, function 0",
      :present         => true,
      :controller_type => "ethernet"
    )
    @host.ems_cluster.should == @cluster
  end

  def assert_specific_vm
    v = ManageIQ::Providers::Microsoft::InfraManager::Vm.find_by_name("ws12r2dc-2DVDs")
    v.should have_attributes(
      :template         => false,
      :ems_ref          => "a9cebab0-5b3a-4c87-923f-554e6168c681",
      :vendor           => "Microsoft",
      :power_state      => "off",
      :location         => "\\\\CFME_HYPERV\\scvmm2\\Virtual Machines\\3DA306DC-48B8-4EC7-829B-B0B458293FAB.xml",
      :tools_status     => "OS shutdown: true, Time synchronization: true, "\
                           "Data exchange: true, Heartbeat: true, Backup: true",
      :boot_time        => nil,
      :connection_state => "connected",
    )
    host2 = Host.find_by_name("qeblade26.cfme-qe-vmm-ad.rhq.lab.eng.bos.redhat.com")

    v.ext_management_system.should eq(@ems)
    v.host.should eq(host2)

    v.operating_system.should have_attributes(
      :product_name => "Windows Server 2012 R2 Datacenter"
    )

    v.custom_attributes.size.should eq(0)
    v.snapshots.size.should eq(1)

    v.hardware.should have_attributes(
      :guest_os           => "Windows Server 2012 R2 Datacenter",
      :guest_os_full_name => "Windows Server 2012 R2 Datacenter",
      :bios               => "67582faa-5b0e-4322-b447-9934db76b9e5",
      :cpu_total_cores    => 1,
      :annotation         => nil,
      :memory_mb          => 2048
    )

    v.hardware.disks.size.should eq(1)
    disk = v.hardware.disks.find_by_device_name("ws12r2dc-07_600E9306-94A1-4710-AB5D-C044DB6C7E8F")
    disk.should have_attributes(
      :device_type     => "disk",
      :controller_type => "IDE",
      :present         => true,
      :filename        => "\\\\CFME_HYPERV\\scvmm2\\ws12r2dc-07_600E9306-94A1-4710-AB5D-C044DB6C7E8F.avhdx",
      :location        => "\\\\CFME_HYPERV\\scvmm2\\ws12r2dc-07_600E9306-94A1-4710-AB5D-C044DB6C7E8F.avhdx",
      :size            => 127.gigabytes,
      :mode            => "persistent",
      :disk_type       => "thin", # TODO: need to add a differencing disk
      :start_connected => true
    )

    v.snapshots.size.should eq(1)
    snapshot = v.snapshots.find_by_name("ws12r2dc-2DVDs - (11/23/2015 14:24:12)")
    snapshot.should have_attributes(
      :uid         => "85D12C23-D8F7-4C7B-82FD-06DCB2EE08BD",
      :ems_ref     => "85D12C23-D8F7-4C7B-82FD-06DCB2EE08BD",
      :parent_uid  => "3DA306DC-48B8-4EC7-829B-B0B458293FAB",
      :name        => "ws12r2dc-2DVDs - (11/23/2015 14:24:12)",
      :description => nil,
    )
    # TODO: Add "Stored" status value in DB. This is a VM that has been provisioned but not deployed

    v.hardware.guest_devices.size.should eq(1)
    dvd1 = v.hardware.guest_devices[0]
    # dvd2 = v.hardware.guest_devices[1]

    dvd1.should have_attributes(
      :device_name     => "CentOS-7-x86_64-DVD-1503-01",
      :device_type     => "cdrom",
      :filename        => "C:\\Users\\administrator.CFME-QE-VMM-AD\\Downloads\\CentOS-7-x86_64-DVD-1503-01.iso",
      :controller_type => "IDE",
      :present         => true,
      :start_connected => true,
    )

    v = Vm.find_by_name("cluster-storage")
    v.hardware.networks.size.should eq(1)
    network = v.hardware.networks.first
    network.should have_attributes(
      :hostname  => "ClusterStore.cfme-qe-vmm-ad.rhq.lab.eng.bos.redhat.com",
      :ipaddress => "10.16.7.235"
    )
  end

  def assert_relationship_tree
    @ems.descendants_arranged.should match_relationship_tree(
      [EmsFolder, "Datacenters", {:is_datacenter => false}] => {
        [EmsFolder, "SCVMM",     {:is_datacenter => true}]  => {
          [EmsFolder, "host",    {:is_datacenter => false}] => {
            [EmsCluster, "hyperv_clus"]                                                        => {},
            [ManageIQ::Providers::Microsoft::InfraManager::Host, "dhcp129-212.brq.redhat.com"] => {},
          },
        [EmsFolder, "vm", {:is_datacenter => false}] => {
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "WS2008R2Core_Tem"]                    => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-hyperv-5.4-2.x86_64"]            => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-hyperv-5.5.0.11-1.x86_64"]       => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-hyperv-5.5.0.12-1.x86_64"]       => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-hyperv-5.5.0.12-1.x86_64a"]      => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-hyperv-5442-tmpl"]               => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-hyperv-5508-tpl"]                => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "cfme-hyperv-5509-tmpl"]               => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "milan tpl with space"]                => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "milan-tpl"]                           => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "milan-tpl with space"]                => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "win7pro64 base"]                      => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "win7pro64-sp1-tpl"]                   => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "win81npro64-base"]                    => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "ws12r2dc-base space"]                 => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "ws2008r2d-sp1-tpl"]                   => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "ws2008s-sp2-tpl"]                     => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Template, "ws2012r2dc-base"]                     => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "Capablanca Appliance"]                      => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "Centos-Test1"]                              => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "New Virtual Machine"]                       => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "Taigo"]                                     => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "VHD-Test2-jp"]                              => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "WS2008R2Core"]                              => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "WS2008R2Corex64Ent"]                        => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "azureone"]                                  => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "bz_migratetest"]                            => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-5.4.3.0-vhd"]                          => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-5509-auto-33"]                         => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-hyperv-5440-h33a"]                     => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-hyperv-5442-x1"]                       => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-hyperv-55010-33"]                      => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-hyperv-55011"]                         => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-hyperv-55012"]                         => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-hyperv-5508-h33a"]                     => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-hyperv-5509-h33a"]                     => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-hyperv-5509-tpl"]                      => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-vhd-5508"]                             => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-vhd-5508-tmpl"]                        => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-vhd-5508-tpl"]                         => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-vhd-937455"]                           => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-vhd-9950059"]                          => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-vhd-9959022"]                          => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-vhd-9962959"]                          => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-vhd-convert-gen2"]                     => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-vhd-convert-test"]                     => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-vpc-541-vhdtest"]                      => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme-vpc-542-ln"]                           => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cfme5.4.3.0.11-vhd"]                        => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "cluster-storage"]                           => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "debug-test-vm"]                             => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "django-win7-jt"]                            => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "gogotqm"]                                   => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "jerryk-1"]                                  => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "jerryk-2"]                                  => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "jt_dnd_w12r2d_dev"]                         => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "jt_dnd_w12r2d_scvmm_dev"]                   => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "scvmm-sp1"]                                 => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "scvmm-sp1-1"]                               => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "scvmm2"]                                    => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "scvmm_vm"]                                  => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "scvmmaz"]                                   => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "smis_netapp_dnd"]                           => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "sprint_demo_vm"]                            => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "test_retire_prov_0BjSoMhMl8"]               => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "testvm"]                                    => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "vm1"]                                       => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "vm_auto_provisioning"]                      => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "vm_extrap_13"]                              => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "vm_extrap_7"]                               => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "vm_extrap_8"]                               => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "vm_extrap_9"]                               => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "vm_extrapolate_name_2"]                     => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "vm_network_2"]                              => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "win10ent64"]                                => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "win10ent64-base-tml"]                       => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "win7pro-azure"]                             => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "win7pro64-sp1"]                             => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "win7pro64-sp1-26"]                          => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "win81prox64_26"]                            => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ws12r2dc-2DVDs"]                            => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ws12r2dc-base-33"]                          => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ws2008-bz1234990"]                          => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ws2008bzz123123123"]                        => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ws2008r2-33a"]                              => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ws2008r2-33b"]                              => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ws2008r2d-sp1-26"]                          => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ws2008s-sp2"]                               => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "ws2008s-sp2-26"]                            => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "vm_extrap_4",
            {:ems_ref => "b11fdee7-1c82-4a1e-a504-c1b978cae690"}]                                         => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "vm_extrap_4",
            {:ems_ref => "18a0e51e-6abb-49e4-99e9-492298bd738d"}]                                         => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "taigotest",
            {:ems_ref => "24e42dc3-d121-42c1-88b6-cf3adcac28a7"}]                                         => {},
          [ManageIQ::Providers::Microsoft::InfraManager::Vm, "taigotest",
            {:ems_ref => "d0681c50-4e31-4204-a2ff-8bc4a32fce7c"}]                                         => {},
          }
        }
      }
    )
  end
end
