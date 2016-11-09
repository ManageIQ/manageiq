describe ApplicationHelper::Button::DialogAction do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  subject { described_class.new(view_context, {}, {'edit' => edit}, {}) }

  context 'when edit' do
    let(:edit) { {:current => current} }
    context 'and edit[:current]' do
      let(:current) { 'something' }
      it { expect(subject.visible?).to be_falsey }
    end
    context 'and edit[:current] == nil' do
      let(:current) { nil }
      it { expect(subject.visible?).to be_truthy }
    end
  end

  context 'when edit == nil' do
    let(:edit) { nil }
    it { expect(subject.visible?).to be_truthy }
  end
end
