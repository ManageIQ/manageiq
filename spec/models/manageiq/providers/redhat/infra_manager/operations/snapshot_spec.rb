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
      allow(Snapshot).to receive(:find_by_id).with(snapshot.id).and_return(snapshot)
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
end
