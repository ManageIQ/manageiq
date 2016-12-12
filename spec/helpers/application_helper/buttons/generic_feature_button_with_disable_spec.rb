describe ApplicationHelper::Button::GenericFeatureButtonWithDisable do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  let(:feature) { :evacuate }
  let(:available) { true }
  let(:record) { FactoryGirl.create(:vm_or_template) }
  let(:button) { described_class.new(view_context, {}, {'record' => record}, {:options => {:feature => feature}}) }
  before do
    allow(record).to receive(:is_available?).with(feature).and_return(available)
    allow(record).to receive(:is_available_now_error_message).and_return('unavailable')
  end

  describe '#disabled?' do
    subject { button.disabled? }

    context 'when feature exists' do
      let(:feature) { :evacuate }
      before do
        allow(record).to receive(:supports_evacuate?).and_return(support)
        allow(record).to receive(:unsupported_reason).and_return('feature not supported')
      end

      context 'when feature is supported' do
        let(:support) { true }
        it { expect(subject).to be_falsey }
      end
      context 'when feature is not supported' do
        let(:support) { false }
        it { expect(subject).to be_truthy }
      end
    end
    context 'when feature is unknown' do
      let(:feature) { :non_existent_feature }

      context 'and feature is not available' do
        let(:available) { false }
        it { expect(subject).to be_truthy }
      end
      context 'but feature is available' do
        it { expect(subject).to be_falsey }
      end
    end
  end
end
