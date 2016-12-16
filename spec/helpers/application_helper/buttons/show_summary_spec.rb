describe ApplicationHelper::Button::ShowSummary do
  subject { described_class.new(setup_view_context_with_sandbox({}), {}, {'explorer' => explorer}, {}) }

  describe '#visible?' do
    [true, false].each do |explorer|
      context "when explorer evals as #{explorer}" do
        let(:explorer) { explorer }
        it { expect(subject.visible?).to eq(!explorer) }
      end
    end
  end
end
