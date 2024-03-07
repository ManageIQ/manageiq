RSpec.describe ManageIQ::Providers::CloudManager::AuthKeyPair do
  let(:ems) { FactoryBot.create(:ems_cloud) }
  let(:user) { FactoryBot.create(:user, :userid => 'test') }
  let(:auth_key_pair) { FactoryBot.create(:auth_key_pair_cloud, :resource => ems) }

  context 'create and delete actions' do
    it "has methods" do
      expect(subject.class.respond_to?(:create_key_pair)).to be true
      expect(subject.respond_to?(:delete_key_pair)).to be true
    end

    # TODO(maufart): do we have any special approach to test module methods separately?
    it 'forces implement methods' do
      expect { subject.delete_key_pair }.to raise_error NotImplementedError
    end

    it 'queues a create task with create_key_pair_queue' do
      task_id = described_class.create_key_pair_queue(user.userid, ems)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "creating Auth Key Pair for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'create_key_pair',
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => ems.my_zone,
        :args        => [ems.id, {}]
      )
    end

    it 'requires a userid and ems for a queued create task' do
      expect { described_class.create_key_pair_queue }.to raise_error(ArgumentError)
      expect { described_class.create_key_pair_queue(user.userid) }.to raise_error(ArgumentError)
    end

    it 'queues a delete task with delete_key_pair_queue' do
      task_id = auth_key_pair.delete_key_pair_queue(user.userid)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "deleting Auth Key Pair for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'delete_key_pair',
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => ems.my_zone,
        :args        => []
      )
    end

    it 'requires a userid for a queued delete task' do
      expect { auth_key_pair.delete_key_pair_queue }.to raise_error(ArgumentError)
    end
  end

  context 'validations' do
    it "fails by default" do
      dummy_cloud_manager = ManageIQ::Providers::CloudManager.new
      dummy_auth_keypair  = ManageIQ::Providers::CloudManager::AuthKeyPair.new
      expect(dummy_cloud_manager.supports?(:auth_key_pair_create)).to eq(false)
      expect(dummy_auth_keypair.supports?(:delete)).to eq(false)
    end
  end
end
