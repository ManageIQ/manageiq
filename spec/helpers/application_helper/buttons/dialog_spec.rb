describe ApplicationHelper::Button::Dialog do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  subject { described_class.new(view_context, {}, {'edit' => edit}, {}) }

  context 'when edit == false' do
    let(:edit) { false }
    it { expect(subject.visible?).to be_falsey }
  end
  context 'when edit does not evaluate as false' do
    let(:edit) { true }
    it { expect(subject.visible?).to be_truthy }
  end
end
