describe ApplicationHelper::Button::DialogResDiscard do
  let(:view_context) { setup_view_context_with_sandbox(:edit_typ => edit_typ) }
  subject { described_class.new(view_context, {}, {'edit' => edit}, {}) }

  context 'when edit' do
    let(:edit) { true }
    context 'and @sb[:edit_typ] == add' do
      let(:edit_typ) { 'add' }
      it { expect(subject.visible?).to be_truthy }
    end
    context 'and @sb[:edit_typ] != add' do
      let(:edit_typ) { 'not_add' }
      it { expect(subject.visible?).to be_falsey }
    end
  end

  context 'when edit == nil' do
    let(:edit) { nil }
    let(:edit_typ) { 'does not matter' }
    it { expect(subject.visible?).to be_falsey }
  end
end
