describe ApplicationHelper::Button::SummaryReload do
  let(:explorer) { true }
  let(:record) { true }
  let(:layout) { 'not_miq_policy_rsop' }
  let(:showtype) { true }
  let(:lastaction) { nil }
  let(:button) do
    described_class.new(setup_view_context_with_sandbox({}), {},
                        {'record' => record, 'explorer' => explorer, 'layout' => layout,
                         'showtype' => showtype, 'lastaction' => lastaction}, {})
  end

  shared_examples 'lastaction_examples' do
    context 'when lastaction == show_list' do
      let(:lastaction) { 'show_list' }
      it { expect(subject).to be_truthy }
    end
    context 'when lastaction != show_list' do
      let(:lastaction) { 'not_show_list' }
      it { expect(subject).to be_falsey }
    end
  end

  describe '#visible?' do
    subject { button.visible? }

    context 'when in explorer' do
      context 'when record set' do
        context 'when layout != miq_policy_rsop' do
          context 'when showtype not in %w(details item)' do
            it { expect(subject).to be_truthy }
          end
          %w(details item).each do |showtype|
            context "when showtype == #{showtype}" do
              let(:showtype) { showtype }
              include_examples 'lastaction_examples'
            end
          end
        end
        context 'when layout == miq_policy_rsop' do
          let(:layout) { 'miq_policy_rsop' }
          include_examples 'lastaction_examples'
        end
      end
      context 'when record not set' do
        let(:record) { false }
        include_examples 'lastaction_examples'
      end
    end
    context 'when not in explorer' do
      let(:explorer) { false }
      it { expect(subject).to be_falsey }
    end
  end
end
