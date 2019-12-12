RSpec.describe ManageIQ::Providers::CloudManager::OrchestrationTemplateRunner do
  let(:zone) { FactoryBot.create(:zone) }
  let(:template) { FactoryBot.create(:orchestration_template) }

  context "#queue_signal" do
    it "queues a signal with the queue_signal method" do
      runner = described_class.new(:options => {:orchestration_template_id => template.id, :zone => zone.id})
      queue = runner.queue_signal

      expect(queue).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'signal',
        :instance_id => template.id,
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => zone.id,
        :priority    => MiqQueue::NORMAL_PRIORITY,
        :args        => []
      )
    end
  end
end
