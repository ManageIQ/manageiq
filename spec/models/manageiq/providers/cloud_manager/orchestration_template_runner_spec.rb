RSpec.describe ManageIQ::Providers::CloudManager::OrchestrationTemplateRunner do
  let(:template) { FactoryBot.create(:orchestration_template) }
  let(:runner) { described_class.new }

  context "#queue_signal" do
    it "queues a signal with the queue_signal method" do
      queue = runner.queue_signal

      expect(queue).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'signal',
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => runner.my_zone,
        :priority    => MiqQueue::NORMAL_PRIORITY,
        :args        => []
      )
    end
  end
end
