describe ApplicationHelper::Button::WidgetNew do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  subject { described_class.new(view_context, {}, {}, {}) }

  before { allow(view_context).to receive(:x_node).and_return(x_node) }

  describe '#visible?' do
    context 'when x_node == root' do
      let(:x_node) { 'root' }
      it { expect(subject.visible?).to be_falsey }
    end
    context 'when x_node != root' do
      let(:x_node) { 'not_root' }
      it { expect(subject.visible?).to be_truthy }
    end
  end
end
