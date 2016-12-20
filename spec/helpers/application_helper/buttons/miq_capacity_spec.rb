describe ApplicationHelper::Button::MiqCapacity do
  let(:view_context) { setup_view_context_with_sandbox(:active_tab => tab) }
  let(:button) { described_class.new(view_context, {}, {}, {}) }

  describe '#visible?' do
    subject { button.visible? }
    context 'when active_tab == report' do
      let(:tab) { 'report' }
      it { is_expected.to be_truthy }
    end
    context 'when active_tab != report' do
      let(:tab) { 'not_report' }
      it { is_expected.to be_falsey }
    end
  end
end
