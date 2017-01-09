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
      expect(Storage.count).to eq(50)
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
  end
end
