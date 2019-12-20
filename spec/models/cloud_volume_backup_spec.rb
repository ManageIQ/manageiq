RSpec.describe CloudVolumeBackup do
  let(:disks) { FactoryBot.create_list(:disk, 2) }
  let(:ems) { FactoryBot.create(:ems_cloud) }
  let(:cloud_volume) { FactoryBot.create(:cloud_volume, :ext_management_system => ems, :attachments => disks) }
  let(:cloud_volume_backup) { FactoryBot.create(:cloud_volume_backup, :ext_management_system => ems) }
  let(:user) { FactoryBot.create(:user, :userid => 'test') }

  context 'queued methods' do
    it 'queues a delete task with delete_queue' do
      task_id = cloud_volume_backup.delete_queue(user.userid)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "deleting Cloud Volume Backup for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'delete',
        :role        => 'ems_operations',
        :queue_name  => ems.queue_name_for_ems_operations,
        :zone        => ems.my_zone,
        :args        => []
      )
    end

    it 'requires a userid for a queued delete task' do
      expect { cloud_volume_backup.delete_queue }.to raise_error(ArgumentError)
    end

    it 'queues a restore task with restore_queue' do
      name = 'test_cloud_volume_backup'
      task_id = cloud_volume_backup.restore_queue(user.userid, cloud_volume.id, name)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "Restoring Cloud Volume Backup for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'restore',
        :role        => 'ems_operations',
        :queue_name  => ems.queue_name_for_ems_operations,
        :zone        => ems.my_zone,
        :args        => [cloud_volume.id, name]
      )
    end
  end
end
