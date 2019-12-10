RSpec.describe ManageIQ::Providers::CloudManager::Template do
  let(:ems) { FactoryBot.create(:ems_cloud) }
  let(:user) { FactoryBot.create(:user, :userid => 'test') }
  let(:cloud_template) { FactoryBot.create(:template_cloud, :ext_management_system => ems) }

  context "actions" do
    it "#post_create_actions" do
      expect(subject).to receive(:reconnect_events)
      expect(subject).to receive(:classify_with_parent_folder_path)
      expect(MiqEvent).to receive(:raise_evm_event).with(subject, "vm_template", :vm => subject)

      subject.post_create_actions
    end
  end

  context "queued methods" do
    it 'queues a create task with create_image_queue' do
      task_id = described_class.create_image_queue(user.userid, ems)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "Creating Cloud Template for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'create_image',
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => ems.my_zone,
        :args        => [ems.id, {}]
      )
    end

    it 'requires a userid and ems for a queued create task' do
      expect { described_class.create_image_queue }.to raise_error(ArgumentError)
      expect { described_class.create_image_queue(user.userid) }.to raise_error(ArgumentError)
    end

    it 'queues an update task with update_image_queue' do
      options = {:name => 'updated_image_name'}
      task_id = cloud_template.update_image_queue(user.userid, options)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "updating Cloud Template for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => cloud_template.class.name).first).to have_attributes(
        :class_name  => cloud_template.class.name,
        :method_name => 'update_image',
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => ems.my_zone,
        :args        => [options]
      )
    end

    it 'requires a userid for a queued update task' do
      expect { cloud_template.update_image_queue }.to raise_error(ArgumentError)
    end

    it 'queues a delete task with delete_image_queue' do
      task_id = cloud_template.delete_image_queue(user.userid)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "Deleting Cloud Template for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'delete_image',
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => ems.my_zone,
        :args        => []
      )
    end

    it 'requires a userid for a queued delete task' do
      expect { cloud_template.delete_image_queue }.to raise_error(ArgumentError)
    end
  end
end
