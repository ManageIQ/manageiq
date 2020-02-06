RSpec.describe VmMigrateTask do
  describe '.do_request' do
    let(:vm) { Vm.new }
    let(:folder) { FactoryBot.create(:ems_folder) }
    before do
      subject.vm = vm
      host = FactoryBot.create(:host, :name => "test")
      subject.update(:options => {:placement_host_name => [host.id, host.name]})
    end

    it 'migrates the vm and updates the status' do
      expect(vm).to receive(:migrate)
      expect(subject).to receive(:update_and_notify_parent).with(hash_including(:state => 'migrated'))
      subject.do_request
    end

    it "doesn't move vm without ems" do
      subject.update(:options => {:placement_folder_name => folder.id})
      expect(subject).to receive(:update_and_notify_parent).with(hash_including(:state => "finished", :status => "Error", :message => "Failed. Reason[VM has no EMS, unable to move VM into a new folder]"))
      subject.do_request
    end

    it "doesn't move vm if already in folder" do
      vm.update(:name => 'aaa', :vendor => 'vmware', :location => 'somewhere')
      vm.ext_management_system = FactoryBot.create(:ext_management_system)
      folder.set_child(vm)
      subject.update(:options => {:placement_folder_name => folder.id})
      expect(subject).to receive(:update_and_notify_parent).with(hash_including(:state => "finished", :status => "Error", :message => "Failed. Reason[The VM '#{vm.name}' is already running on the same folder as the destination.]"))
      subject.do_request
    end

    it "moves vm" do
      vm.update(:name => 'aaa', :vendor => 'vmware', :location => 'somewhere')
      vm.ext_management_system = FactoryBot.create(:ext_management_system, :with_authentication)
      subject.update(:options => {:placement_folder_name => folder.id})
      expect(vm).to receive(:raw_move_into_folder).with(folder)
      expect(subject).to receive(:update_and_notify_parent).with(hash_including(:state => "migrated", :status => "Ok", :message => "Finished VM Migrate"))
      subject.do_request
    end

    it "catches migrate error and update the status" do
      expect(vm).to receive(:migrate).and_raise("Bad things happened")
      expect(subject).to receive(:update_and_notify_parent).with(hash_including(:state => 'finished', :status => 'Error', :message => 'Failed. Reason[Bad things happened]'))
      subject.do_request
    end
  end
end
