describe ApplicationHelper::Button::InstanceCheckCompare do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  let(:display) { nil }
  let(:record) { FactoryGirl.create(:vm) }
  subject { described_class.new(view_context, {}, {'record' => record, 'display' => display}, {}) }

  describe '#visible?' do
    context 'when record is not kind of OrchestrationStack && display != instances' do
      it { expect(subject.visible?).to be_truthy }
    end
    context 'when record is kind of OrchestrationStack && display != instances' do
      let(:record) { FactoryGirl.create(:orchestration_stack) }
      it { expect(subject.visible?).to be_truthy }
    end
    context 'when record is an OrchestrationStack && display == instances' do
      let(:record) { FactoryGirl.create(:orchestration_stack) }
      let(:display) { 'instances' }
      it { expect(subject.visible?).to be_falsey }
    end
  end

  describe '#disabled?' do
    before { allow(record).to receive(:has_compliance_policies?).and_return(has_policies) }

    context 'when record has compliance policies' do
      let(:has_policies) { true }
      it { expect(subject.disabled?).to be_falsey }
    end
    context 'when record does not have compliance policies' do
      let(:has_policies) { false }
      it { expect(subject.disabled?).to be_truthy }
    end
  end
end
