RSpec.describe VmOrTemplate::Operations::Snapshot do
  before { EvmSpecHelper.local_miq_server }

  let(:ems)      { FactoryBot.create(:ems_vmware) }
  let(:vm)       { FactoryBot.create(:vm_vmware, :ext_management_system => ems) }
  let(:snapshot) { FactoryBot.create(:snapshot, :vm_or_template => vm) }

  context "queued methods" do
    it 'queues an update task with remove_snapshot_queue' do
      queue = vm.remove_snapshot_queue(snapshot.id)

      expect(queue).to have_attributes(
        :class_name  => vm.class.name,
        :method_name => 'remove_snapshot',
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => vm.my_zone,
        :args        => [snapshot.id],
        :task_id     => nil
      )
    end

    it 'queues an update task with remove_evm_snapshot_queue' do
      queue = vm.remove_evm_snapshot_queue(snapshot.id)

      expect(queue).to have_attributes(
        :class_name  => vm.class.name,
        :method_name => 'remove_evm_snapshot',
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => vm.my_zone,
        :args        => [snapshot.id],
        :task_id     => nil
      )
    end
  end
end
