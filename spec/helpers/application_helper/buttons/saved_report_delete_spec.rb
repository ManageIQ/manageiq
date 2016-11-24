describe ApplicationHelper::Button::SavedReportDelete do
  let(:view_context) { setup_view_context_with_sandbox(:active_tree => tree, :active_tab => tab) }
  let(:tab) { nil }
  subject { described_class.new(view_context, {}, {}, {}) }

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
    context 'when active_tree != reports_tree' do
      let(:tree) { :savedreports_tree }
      it { expect(subject.visible?).to be_truthy }
    end
  end
end
