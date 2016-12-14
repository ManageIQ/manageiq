describe ApplicationHelper::Button::Reload do
  let(:view_context) { setup_view_context_with_sandbox(:active_tree => tree, :active_tab => tab) }
  let(:x_node) { nil }
  let(:tree) { nil }
  let(:tab) { nil }
  subject { described_class.new(view_context, {}, {}, {}) }

  before { allow(view_context).to receive(:x_node).and_return(x_node) }

  describe '#visible?' do
    context 'when active_tree == reports_tree' do
      let(:tree) { :reports_tree }
      context 'and active_tab == saved_reports' do
        let(:tab) { 'saved_reports' }
        it { expect(subject.visible?).to be_truthy }
      end
      context 'and active_tab != saved_reports' do
        let(:tab) { 'not_saved_reports' }
        it { expect(subject.visible?).to be_falsey }
      end
    end
    context 'when active_tree == savedreports_tree' do
      let(:tree) { :savedreports_tree }
      context 'and x_node == root' do
        let(:x_node) { 'root' }
        it { expect(subject.visible?).to be_truthy }
      end
      context 'and x_node != root' do
        let(:x_node) { 'not_root' }
        it { expect(subject.visible?).to be_falsey }
      end
    end
    context 'when active_tree != reports_tree && active_tree != savedreports_tree' do
      let(:tree) { :not_any_of_reports_trees }
      it { expect(subject.visible?).to be_truthy }
    end
  end
end
