describe ApplicationHelper::Button::MiqReportAction do
  let(:view_context) { setup_view_context_with_sandbox(:active_tab => tab) }
  subject { described_class.new(view_context, {}, {}, {}) }

  describe '#visible?' do
    context 'when active_tab == saved_reports' do
      let(:tab) { 'saved_reports' }
      it { expect(subject.visible?).to be_falsey }
    end
    context 'when active_tab != saved_reports' do
      let(:tab) { 'does_not_matter' }
      it { expect(subject.visible?).to be_truthy }
    end
  end
end
