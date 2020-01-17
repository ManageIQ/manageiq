RSpec.describe ManageIQ::Providers::ContainerManager::OrchestrationStack do
  let(:stack) { FactoryBot.create(:orchestration_stack_container) }

  describe '#retire_now' do
    it 'retires the orchestration stack' do
      expect(stack).to receive(:finish_retirement).once
      stack.retire_now
    end
  end
end
