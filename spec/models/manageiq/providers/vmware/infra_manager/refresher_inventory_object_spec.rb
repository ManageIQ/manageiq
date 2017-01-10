require Rails.root.join('spec/tools/vim_data/vim_data_test_helper')

describe ManageIQ::Providers::Vmware::InfraManager::Refresher do
  before do
    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(
      :ems_vmware_with_authentication,
      :zone => zone, :name => "VC41Test-Prod",
      :hostname => "VC41Test-Prod.MIQTEST.LOCAL",
      :ipaddress => "192.168.252.14"
    )

    allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager)
      .to receive(:connect).and_return(FakeMiqVimHandle.new)
    allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager)
      .to receive(:disconnect).and_return(true)
    allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager)
      .to receive(:has_credentials?).and_return(true)
  end

  context "Inventory Object Refresh" do
    let(:settings) do
      {
        :ems_refresh => {
          :vmwarews => {
            :inventory_object_refresh => true
          }
        }
      }
    end
    before do
      stub_settings(settings)
    end

    it "will perform a full refresh" do
      EmsRefresh.refresh(@ems)
      @ems.reload

      assert_table_counts
      assert_ems
      assert_specific_storage
      assert_specific_storage_profile
    end

    def assert_table_counts
      expect(ExtManagementSystem.count).to eq(1)
      expect(Datacenter.count).to eq(3)
      expect(EmsFolder.count).to eq(31)
      expect(EmsCluster.count).to eq(1)
      expect(Host.count).to eq(4)
      expect(ResourcePool.count).to eq(17)
      expect(VmOrTemplate.count).to eq(101)
      expect(Vm.count).to eq(92)
      expect(MiqTemplate.count).to eq(9)
      expect(Storage.count).to eq(33)
      expect(StorageProfile.count).to eq(6)

      expect(CustomAttribute.count).to eq(3)
      expect(CustomizationSpec.count).to eq(2)
      expect(Disk.count).to eq(421)
      expect(GuestDevice.count).to eq(135)
      expect(Hardware.count).to eq(105)
      expect(Lan.count).to eq(16)
      expect(MiqScsiLun.count).to eq(73)
      expect(MiqScsiTarget.count).to eq(73)
      expect(Network.count).to eq(75)
      expect(OperatingSystem.count).to eq(105)
      expect(Snapshot.count).to eq(29)
      expect(Switch.count).to eq(9)
      expect(SystemService.count).to eq(29)

      expect(Relationship.count).to eq(246)
      expect(MiqQueue.count).to eq(101)
    end

    def assert_ems
      expect(@ems).to have_attributes(
        :api_version => "4.1",
        :uid_ems     => "EF53782F-6F1A-4471-B338-72B27774AFDD"
      )

      expect(@ems.ems_folders.size).to eq(31)
      expect(@ems.ems_clusters.size).to eq(1)
      expect(@ems.resource_pools.size).to eq(17)
      expect(@ems.storages.size).to eq(47)
      expect(@ems.hosts.size).to eq(4)
      expect(@ems.vms_and_templates.size).to eq(101)
      expect(@ems.vms.size).to eq(92)
      expect(@ems.miq_templates.size).to eq(9)
      expect(@ems.storage_profiles.size).to eq(6)

      expect(@ems.customization_specs.size).to eq(2)
      cspec = @ems.customization_specs.find_by_name("Win2k8Template")
      expect(cspec).to have_attributes(
        :name             => "Win2k8Template",
        :typ              => "Windows",
        :description      => "",
        :last_update_time => Time.parse("2011-05-17T15:54:37Z")
      )
      expect(cspec.spec).to      be_a_kind_of(VimHash)
      expect(cspec.spec.keys).to match_array(%w(identity encryptionKey nicSettingMap globalIPSettings options))
    end

    def assert_specific_storage
      @storage = Storage.find_by_name("StarM1-Prod1 (1)")
      expect(@storage).to have_attributes(
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

    def assert_specific_storage_profile
      @storage_profile = StorageProfile.find_by(:name => "Virtual SAN Default Storage Policy")
      expect(@storage_profile).to have_attributes(
        :ems_id       => @ems.id,
        :ems_ref      => "aa6d5a82-1c88-45da-85d3-3d74b91a5bad",
        :name         => "Virtual SAN Default Storage Policy",
        :profile_type => "REQUIREMENT"
      )

      expect(@storage_profile.storages).to include(@storage)
      expect(@storage.storage_profiles).to include(@storage_profile)
    end
  end
end
