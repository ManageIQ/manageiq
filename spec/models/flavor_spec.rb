RSpec.describe Flavor do
  let(:ems) { FactoryBot.create(:ems_openstack) }
  let(:flavor) { FactoryBot.create(:flavor, :name => 'large', :ext_management_system => ems) }
  let(:user) { FactoryBot.create(:user, :userid => 'test') }

  context 'when calling raw_create_flavor methods' do
    it 'raises NotImplementedError' do
      expect do
        subject.class.raw_create_flavor(1, {})
      end.to raise_error(NotImplementedError, "raw_create_flavor must be implemented in a subclass")
    end
  end

  context 'when calling raw_create_flavor methods' do
    it 'raises NotImplementedError' do
      expect do
        subject.raw_delete_flavor
      end.to raise_error(NotImplementedError, "raw_delete_flavor must be implemented in a subclass")
    end
  end

  context 'when calling create_flavor method' do
    it 'should call raw_create_flavor' do
      flavor_double = class_double('ManageIQ::Providers::Openstack::CloudManager::Flavor')
      allow(subject.class).to receive(:class_by_ems).and_return(flavor_double)
      expect(flavor_double).to receive(:raw_create_flavor)
      subject.class.create_flavor(ems.id, {})
    end
  end

  context 'when calling delete_flavor method' do
    it 'should call raw_delete_flavor' do
      expect(subject).to receive(:raw_delete_flavor)
      subject.delete_flavor
    end
  end

  context 'queued methods' do
    it 'queues a create task with create_flavor_queue' do
      task_id = described_class.create_flavor_queue(user.userid, ems)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "Creating flavor for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'create_flavor',
        :role        => 'ems_operations',
        :zone        => ems.my_zone,
        :args        => [ems.id, {}]
      )
    end

    it 'requires a userid and ems for a queued create task' do
      expect { described_class.create_flavor_queue }.to raise_error(ArgumentError)
      expect { described_class.create_flavor_queue(user.userid) }.to raise_error(ArgumentError)
    end

    it 'queues a delete task with delete_flavor_queue' do
      task_id = flavor.delete_flavor_queue(user.userid)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "Deleting flavor for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'delete_flavor',
        :role        => 'ems_operations',
        :zone        => ems.my_zone,
        :args        => []
      )
    end

    it 'requires a userid for a queued delete task' do
      expect { flavor.delete_flavor_queue }.to raise_error(ArgumentError)
    end
  end
end
