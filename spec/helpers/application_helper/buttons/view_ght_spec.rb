describe ApplicationHelper::Button::ViewGHT do
  let(:view_context) { setup_view_context_with_sandbox(:active_tree => tree) }
  let(:ght_type) { 'tabular' }
  let(:report) { FactoryGirl.create(:miq_report) }
  let(:zgraph) { nil }
  let(:graph) { nil }
  subject do
    described_class.new(view_context, {},
                        { 'ght_type' => ght_type,
                          'report'   => report,
                          'zgraph'   => zgraph }, {})
  end

  before { allow(report).to receive(:graph).and_return(graph) }

  describe '#visible?' do
    %w(reports_tree savedreports_tree).each do |tree|
      context "when x_active_tree == #{tree}" do
        let(:tree) { tree.to_sym }
        context 'when ght_type != tabular' do
          let(:ght_type) { 'hybrid' }
          it { expect(subject.visible?).to be_truthy }
        end
        context 'when report has graph' do
          let(:graph) { true }
          it { expect(subject.visible?).to be_truthy }
        end
        context 'when zgraph is available' do
          let(:zgraph) { true }
          it { expect(subject.visible?).to be_truthy }
        end
        context 'when ght_type == tabular && report does not have graph && not a zgraph' do
          it { expect(subject.visible?).to be_falsey }
        end
      end
    end
    context 'when !%w(reports_tree savedreports_tree).include?(x_active_tree)' do
      let(:tree) { :not_any_of_reports_trees }
      it { expect(subject.visible?).to be_truthy }
    end
  end
end
