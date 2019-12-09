RSpec.describe TemplateCloud do
  let(:ems) { FactoryBot.create(:ems_cloud) }
  let(:user) { FactoryBot.create(:user, :userid => 'test') }

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
  end
end
