describe VmMigrateTask do
  describe '.do_request' do
    let(:vm) { Vm.new }
    before { subject.vm = vm }

    it 'migrates the vm and updates the status' do
      expect(vm).to receive(:migrate)
      expect(subject).to receive(:update_and_notify_parent).with(hash_including(:state => 'migrated'))
      subject.do_request
    end

    it 'catches migrate error and update the status' do
      expect(vm).to receive(:migrate).and_raise("Bad things happened")
      expect(subject).to receive(:update_and_notify_parent).with(hash_including(:state => 'finished', :status => 'error', :message => 'Failed. Reason[Bad things happened]'))
      subject.do_request
    end
  end
end
