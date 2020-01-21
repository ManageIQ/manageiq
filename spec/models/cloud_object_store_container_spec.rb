RSpec.describe CloudObjectStoreContainer do
  let(:ems) { FactoryBot.create(:ems_cloud) }
  let(:user) { FactoryBot.create(:user, :userid => 'test') }

  context "queued methods" do
    it 'queues a create task with cloud_object_store_container_create_queue' do
      task_id = described_class.cloud_object_store_container_create_queue(user.userid, ems)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "creating Cloud Object Store Container for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'cloud_object_store_container_create',
        :role        => 'ems_operations',
        :queue_name  => ems.queue_name_for_ems_operations,
        :zone        => ems.my_zone,
        :args        => [ems.id, {}]
      )
    end

    it 'requires a userid and ems for a queued create task' do
      expect { described_class.cloud_object_store_container_create_queue }.to raise_error(ArgumentError)
      expect { described_class.cloud_object_store_container_create_queue(user.userid) }.to raise_error(ArgumentError)
    end
  end
end
