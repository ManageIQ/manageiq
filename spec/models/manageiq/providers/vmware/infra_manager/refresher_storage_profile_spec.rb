require Rails.root.join('spec/tools/vim_data/vim_data_test_helper')

describe ManageIQ::Providers::Vmware::InfraManager::Refresher do
  let(:zone) { EvmSpecHelper.create_guid_miq_server_zone[2] }
  let(:ems) do
    FactoryGirl.create(
      :ems_vmware_with_authentication,
      :zone => zone, :name => "VC41Test-Prod",
      :hostname => "VC41Test-Prod.MIQTEST.LOCAL",
      :ipaddress => "192.168.252.14"
    )
  end

  before(:each) do
    allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager)
      .to receive(:connect).and_return(FakeMiqVimHandle.new)
    allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager)
      .to receive(:disconnect).and_return(true)
    allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager)
      .to receive(:has_credentials?).and_return(true)

    EmsRefresh.refresh(ems)
  end

  context 'Association of storage profile with storages' do
    let(:storage_profile_ref) { 'aa6d5a82-1c88-45da-85d3-3d74b91a5bad' }
    let(:storage_profile) { StorageProfile.find_by(:ems_ref => storage_profile_ref) }
    let(:storage_location) { '4d3f9f09-38b9b7dc-365d-0010187f00da' }
    let(:storage) { Storage.find_by(:ems_ref => 'datastore-953') }

    it 'links a storage profile to datastores' do
      expect(storage.storage_profiles).to include(storage_profile)
      expect(storage_profile.storages).to include(storage)
    end

    it 'handles storage profile deletion' do
      profile_assoc_count = StorageProfileStorage.count
      refresher         = ems.refresher.new([ems])
      target, inventory = refresher.collect_inventory_for_targets(ems, [ems])[0]

      inventory[:storage_profile].delete(storage_profile_ref)
      inventory[:storage_profile_entity].delete(storage_profile_ref)

      hashes = refresher.parse_targeted_inventory(ems, target, inventory)
      refresher.save_inventory(ems, target, hashes)

      storage = Storage.find_by(:location => storage_location)
      expect(storage.storage_profiles).not_to include(storage_profile)
      expect(StorageProfileStorage.count).to eql(profile_assoc_count - 1)
    end
  end

  context "Association of storage profile with VMs/disks" do
    let(:storage_profile_ref) { '6fe1c7b4-7f7e-4db1-a545-c756e392de62' }
    let(:storage_profile) { StorageProfile.find_by(:ems_ref => storage_profile_ref) }
    let(:vm) { Vm.find_by(:ems_ref => 'vm-901') }
    let(:host) { Host.find_by(:ems_ref => 'host-648') }
    let(:disk) { vm.disks.detect { |d| d.device_type == 'disk' } } # only 1 disk in this vm

    it 'links a storage profile to VMs' do
      expect(storage_profile.vms_and_templates).to include(vm)
      expect(vm.storage_profile).to eq(storage_profile)
    end

    it 'links a storage profile to disks' do
      expect(disk.storage_profile).to eq(storage_profile)
      expect(storage_profile.disks).to include(disk)
    end

    it 'will not delete storage_profiles or clear the associations when target refreshing a VM' do
      num_storage_profiles = StorageProfile.count

      refresher = ems.refresher.new([vm])
      # full ems refresh
      target, inventory = refresher.collect_inventory_for_targets(ems, [ems])[0]
      hashes = refresher.parse_targeted_inventory(ems, target, inventory)
      refresher.save_inventory(ems, target, hashes)
      expect(StorageProfile.count).to eq(num_storage_profiles)

      # vm-targeted refresh
      target, inventory = refresher.collect_inventory_for_targets(ems, [vm])[0]
      hashes = refresher.parse_targeted_inventory(ems, target, inventory)
      refresher.save_inventory(ems, target, hashes)
      expect(StorageProfile.count).to eq(num_storage_profiles)

      vm.reload
      expect(vm.storage_profile).to eq(storage_profile)
    end

    it 'will not delete storage_profiles or clear the associations when target refreshing a host' do
      num_storage_profiles = StorageProfile.count

      refresher = ems.refresher.new([host])
      # full ems refresh
      target, inventory = refresher.collect_inventory_for_targets(ems, [ems])[0]
      hashes = refresher.parse_targeted_inventory(ems, target, inventory)
      refresher.save_inventory(ems, target, hashes)
      expect(StorageProfile.count).to eq(num_storage_profiles)

      # host-targeted refresh
      target, inventory = refresher.collect_inventory_for_targets(ems, [host])[0]
      hashes = refresher.parse_targeted_inventory(ems, target, inventory)
      refresher.save_inventory(ems, target, hashes)
      expect(StorageProfile.count).to eq(num_storage_profiles)
    end

    it 'clears the association when the storage profile of a VM/Disk is deleted' do
      refresher = ems.refresher.new([ems])
      target, inventory = refresher.collect_inventory_for_targets(ems, [ems])[0]
      expect(inventory[:storage_profile_entity].size).to eql(6)
      inventory[:storage_profile].delete(storage_profile_ref)
      inventory[:storage_profile_entity].delete(storage_profile_ref)

      hashes = refresher.parse_targeted_inventory(ems, target, inventory)
      refresher.save_inventory(ems, target, hashes)
      vm.reload
      disk.reload
      expect(StorageProfile.find_by(:ems_ref => storage_profile_ref)).to be_nil
      expect(vm.storage_profile).to be_nil
      expect(disk.storage_profile).to be_nil
    end

    it 'clears the association when the storage profile is detached from a VM and its disk' do
      refresher = ems.refresher.new([ems])
      target, inventory = refresher.collect_inventory_for_targets(ems, [ems])[0]
      expect(inventory[:storage_profile_entity].size).to eql(6)
      inventory[:storage_profile_entity][storage_profile_ref].reject! { |e| e.key.match(/^vm-901/) }

      hashes = refresher.parse_targeted_inventory(ems, target, inventory)
      refresher.save_inventory(ems, target, hashes)
      storage_profile.reload
      vm.reload
      disk.reload
      expect(storage_profile).not_to be_nil
      expect(vm.storage_profile).to be_nil
      expect(disk.storage_profile).to be_nil
    end
  end
end
