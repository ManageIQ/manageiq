RSpec.describe ManageIQ::Providers::CloudManager::OrchestrationTemplateRunner do
  let(:zone) { FactoryBot.create(:zone) }
  let(:template) { FactoryBot.create(:orchestration_template) }

  context "#queue_signal" do
    it "queues a signal with the queue_signal method" do
      runner = described_class.create_job(:options => {:orchestration_template_id => template.id}, :zone => zone.name)
      queue = runner.queue_signal

      expect(queue).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'signal',
        :instance_id => runner.id,
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => zone.name,
        :priority    => MiqQueue::NORMAL_PRIORITY,
        :args        => []
      )
    end
  end
end
