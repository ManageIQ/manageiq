describe ApplicationHelper::Button::AbButtonNew do
  subject { described_class.new(view_context, {}, {}, {}) }

  before { allow(view_context).to receive(:x_node).and_return(x_node) }

  describe '#visible?' do
    context 'when x_active_tree != :ab_tree' do
      let(:view_context) { setup_view_context_with_sandbox(:active_tree => :not_ab_tree) }
      let(:x_node) { 'xx-ab_11784' }
      it { expect(subject.visible?).to be_truthy }
    end
    context 'when x_active_tree == :ab_tree' do
      let(:view_context) { setup_view_context_with_sandbox(:active_tree => :ab_tree) }
      context ' and x_node cannot be split into 2 parts' do
        let(:x_node) { 'xx-ab' }
        it { expect(subject.visible?).to be_truthy }
      end
      context 'and x_node does not start with xx-ab' do
        let(:x_node) { 'ab_11784' }
        it { expect(subject.visible?).to be_truthy }
      end
      context 'and x_node looks like xx-ab_12345' do
        let(:x_node) { 'xx-ab_12345' }
        it { expect(subject.visible?).to be_falsey }
      end
    end
  end
end
