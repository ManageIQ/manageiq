describe ManageIQ::Providers::Redhat::InfraManager::Vm::Operations::Snapshot do
  describe 'calling snapshot operations' do
    let(:vm) { FactoryGirl.create(:vm_redhat) }
    let!(:snapshot) { double("snapshot", :id => 1, :uid_ems => 'ems_id_111') }
    before(:each) do
      @snapshot_service = double('snapshot_service')
      @closeable_snapshots_service = double('snapshots_service')
      allow(@closeable_snapshots_service).to receive(:close).and_return(nil)
      allow(@closeable_snapshots_service).to receive(:snapshot_service)
        .with(snapshot.uid_ems) { @snapshot_service }
      allow(vm).to receive(:closeable_snapshots_service).with(any_args).and_return(@closeable_snapshots_service)
      allow(Snapshot).to receive(:find_by).with(:id => snapshot.id).and_return(snapshot)
    end

    it 'calls remove on the snapshot service' do
      expect(@snapshot_service).to receive(:remove)
      vm.raw_remove_snapshot(snapshot.id)
    end

    it 'calls revert on the snapshot service' do
      expect(@snapshot_service).to receive(:restore)
      vm.raw_revert_to_snapshot(snapshot.id)
    end

    it 'calls revert on the snapshot service' do
      expect(@closeable_snapshots_service).to receive(:add)
        .with(:description => "snap_desc", :persist_memorystate => true)
      vm.raw_create_snapshot(nil, "snap_desc", true)
    end
  end

  describe 'supported above api v4' do
    let(:ems) { FactoryGirl.create(:ems_redhat_with_authentication) }
    let(:vm)  { FactoryGirl.create(:vm_redhat, :ext_management_system => ems) }
    let(:supported_api_versions) { [] }
    before(:each) do
      allow(ems).to receive(:supported_api_versions).and_return(supported_api_versions)
    end
    subject { vm.supports_snapshots? }
    context 'when engine supports v4 api' do
      let(:supported_api_versions) { [4] }
      it { is_expected.to be_truthy }
    end

    context 'when engine does not support v4 api' do
      let(:supported_api_versions) { [3] }
      it { is_expected.to be_falsey }
    end
  end
end
