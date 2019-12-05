RSpec.describe CloudVolumeSnapshot do
  let(:ems) { FactoryBot.create(:ems_openstack) }
  let(:snapshot) { FactoryBot.create(:cloud_volume_snapshot, :ext_management_system => ems) }

  context "queued methods" do
    it 'queues a delete task with delete_snapshot_queue' do
      task_id = snapshot.delete_snapshot_queue

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "deleting volume snapshot for system in #{ems.name}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'delete_snapshot',
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => ems.my_zone,
        :args        => []
      )
    end
  end
end
