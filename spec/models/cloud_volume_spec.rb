RSpec.describe CloudVolume do
  let(:disks) { FactoryBot.create_list(:disk, 2) }
  let(:ems) { FactoryBot.create(:ems_cloud) }
  let(:cloud_volume) { FactoryBot.create(:cloud_volume, :ext_management_system => ems, :attachments => disks) }
  let(:user) { FactoryBot.create(:user, :userid => 'test') }

  it ".available" do
    cloud_volumes_no_backing_disks = FactoryBot.create_list(:cloud_volume, 2)
    expect(described_class.available).to eq(cloud_volumes_no_backing_disks)
  end

  context 'queued methods' do
    it 'queues a create task with create_volume_queue' do
      task_id = described_class.create_volume_queue(user.userid, ems)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "creating Cloud Volume for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'create_volume',
        :role        => 'ems_operations',
        :queue_name  => ems.queue_name_for_ems_operations,
        :zone        => ems.my_zone,
        :args        => [ems.id, {}]
      )
    end

    it 'requires a userid and ems for a queued create task' do
      expect { described_class.create_volume_queue }.to raise_error(ArgumentError)
      expect { described_class.create_volume_queue(user.userid) }.to raise_error(ArgumentError)
    end

    it 'queues an update task with update_volume_queue' do
      options = {:name => 'updated_volume_name'}
      task_id = cloud_volume.update_volume_queue(user.userid, options)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "updating Cloud Volume for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'update_volume',
        :role        => 'ems_operations',
        :queue_name  => ems.queue_name_for_ems_operations,
        :zone        => ems.my_zone,
        :args        => [options]
      )
    end

    it 'requires a userid for a queued update task' do
      expect { cloud_volume.update_volume_queue }.to raise_error(ArgumentError)
    end

    it 'queues a delete task with delete_volume_queue' do
      task_id = cloud_volume.delete_volume_queue(user.userid)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "deleting Cloud Volume for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'delete_volume',
        :role        => 'ems_operations',
        :queue_name  => ems.queue_name_for_ems_operations,
        :zone        => ems.my_zone,
        :args        => []
      )
    end

    it 'requires a userid for a queued delete task' do
      expect { cloud_volume.delete_volume_queue }.to raise_error(ArgumentError)
    end
  end
end
