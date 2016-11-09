describe ApplicationHelper::Button::DialogAddBox do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  subject { described_class.new(view_context, {}, {'edit' => edit}, {}) }

  before { allow(view_context).to receive(:x_node).and_return(x_node) }

  context 'when edit' do
    let(:edit) { true }
    context 'and x_node.length < 2' do
      let(:x_node) { 'xx' }
      it { expect(subject.visible?).to be_falsey }
    end
    context 'and x_node.length == 2' do
      let(:x_node) { 'xx_12' }
      it { expect(subject.visible?).to be_truthy }
    end
    context 'and x_node.length == 3' do
      let(:x_node) { 'xx_aa_12' }
      it { expect(subject.visible?).to be_truthy }
    end
    context 'and x_node.length > 3' do
      let(:x_node) { 'xx_aa_12_34' }
      it { expect(subject.visible?).to be_falsey }
    end
  end

  context 'when edit == nil' do
    let(:edit) { nil }
    let(:x_node) { 'does_not_matter' }
    it { expect(subject.visible?).to be_falsey }
  end
end
