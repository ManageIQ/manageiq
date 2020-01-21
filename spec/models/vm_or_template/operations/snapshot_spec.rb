RSpec.describe VmOrTemplate::Operations::Snapshot do
  before { EvmSpecHelper.local_miq_server }
  after(:context) { MiqQueue.delete_all }

  let(:user)       { FactoryBot.create(:user, :userid => 'test') }
  let(:ems)        { FactoryBot.create(:ems_vmware) }
  let(:vm)         { FactoryBot.create(:vm_vmware, :ext_management_system => ems) }
  let(:snapshots)  { FactoryBot.create_list(:snapshot, 2, :vm_or_template => vm) }

  context "queued methods" do
    it 'queues as expected in remove_snapshot_queue' do
      queue = vm.remove_snapshot_queue(snapshots.first.id)

      expect(queue).to have_attributes(
        :class_name  => vm.class.name,
        :method_name => 'remove_snapshot',
        :role        => 'ems_operations',
        :queue_name  => vm.queue_name_for_ems_operations,
        :zone        => vm.my_zone,
        :args        => [snapshots.first.id],
        :task_id     => nil
      )
    end

    it 'queues as expected with remove_evm_snapshot_queue' do
      queue = vm.remove_evm_snapshot_queue(snapshots.first.id)

      expect(queue).to have_attributes(
        :class_name  => vm.class.name,
        :method_name => 'remove_evm_snapshot',
        :role        => 'ems_operations',
        :queue_name  => vm.queue_name_for_ems_operations,
        :zone        => vm.my_zone,
        :args        => [snapshots.first.id],
        :task_id     => nil
      )
    end

    it 'queues an update task with remove_all_snapshots_queue' do
      task_id = vm.remove_all_snapshots_queue(user.userid)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "Removing all snapshots for #{vm.name}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => vm.class.name).first).to have_attributes(
        :class_name  => vm.class.name,
        :method_name => 'remove_all_snapshots',
        :role        => 'ems_operations',
        :queue_name  => ems.queue_name_for_ems_operations,
        :zone        => ems.my_zone,
        :args        => []
      )
    end
  end
end
