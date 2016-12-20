describe ApplicationHelper::Button::MiqRequestReload do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  let(:action) { 'not_show_list' }
  let(:type) { 'not_miq_provisions' }
  let(:button) { described_class.new(view_context, {}, {'lastaction' => action, 'showtype' => type}, {}) }

  describe '#visible?' do
    subject { button.visible? }
    context 'when lastaction != show_list' do
      context 'showtype != miq_provisions' do
        it { is_expected.to be_falsey }
      end
      context 'and showtype == miq_provisions' do
        let(:type) { 'miq_provisions' }
        it { is_expected.to be_truthy }
      end
    end
    context 'when lastaction == show_list' do
      let(:action) { 'show_list' }
      context 'and showtype != miq_provisions' do
        it { is_expected.to be_truthy }
      end
      context 'and showtype == miq_provisions' do
        let(:type) { 'miq_provisions' }
        it { is_expected.to be_truthy }
      end
    end
  end
end
