describe ApplicationHelper::Button::DialogResourceRemove do
  let(:view_context) { setup_view_context_with_sandbox(:edit_typ => edit_typ) }
  subject { described_class.new(view_context, {}, {'edit' => edit}, {}) }

  before { allow(view_context).to receive(:x_node).and_return(x_node) }

  context 'when edit' do
    let(:edit) { true }
    context 'when edit_typ == add' do
      let(:edit_typ) { 'add' }
      let(:x_node) { 'does_not_matter' }
      it { expect(subject.visible?).to be_falsey }
    end
    context 'when edit_typ != add' do
      let(:edit_typ) { 'not_add' }
      context 'and x_node == root' do
        let(:x_node) { 'root' }
        it { expect(subject.visible?).to be_falsey }
      end
      context 'and x_node != root' do
        let(:x_node) { 'not_root' }
        it { expect(subject.visible?).to be_truthy }
      end
    end
  end

  context 'when edit == nil' do
    let(:edit) { nil }
    let(:edit_typ) { 'does not matter' }
    let(:x_node) { 'does_not_matter' }
    it { expect(subject.visible?).to be_falsey }
  end
end
