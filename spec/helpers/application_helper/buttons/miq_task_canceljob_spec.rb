describe ApplicationHelper::Button::MiqTaskCanceljob do
  let(:button) { described_class.new(setup_view_context_with_sandbox({}), {}, {'layout' => layout}, {}) }

  describe '#visible?' do
    subject { button.visible? }
    %w(all_tasks all_ui_tasks).each do |layout|
      context "when layout == #{layout}" do
        let(:layout) { layout }
        it { is_expected.to be_falsey }
      end
    end
    context 'when !layout.in(%w(all_tasks all_ui_tasks))' do
      let(:layout) { 'something' }
      it { is_expected.to be_truthy }
    end
  end
end
