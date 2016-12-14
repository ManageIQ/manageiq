describe ApplicationHelper::Button::WidgetGenerateContent do
  let(:view_context) { setup_view_context_with_sandbox(:wtype => wtype) }
  let(:record) do
    rec = FactoryGirl.create(:miq_widget)
    set = FactoryGirl.create(:miq_widget_set)
    w_set_rel = FactoryGirl.create(:relationship_miq_widget_set_with_membership, :resource_id => set.id)
    FactoryGirl.create(:relationship_miq_widget_with_membership, :resource_id => rec.id, :ancestry => w_set_rel.id)
    rec
  end
  let(:widget_running) { false }
  let(:wtype) { 'not_m' }
  subject { described_class.new(view_context, {}, {'record' => record, 'widget_running' => widget_running}, {}) }

  describe '#visible?' do
    context 'when it is a menu widget' do
      let(:wtype) { 'm' }
      it { expect(subject.visible?).to be_falsey }
    end
    context 'when it is not a menu widget' do
      it { expect(subject.visible?).to be_truthy }
    end
  end

  describe '#disabled?' do
    context 'when widget is not assigned to any dashboard' do
      let(:record) { FactoryGirl.create(:miq_widget) }
      it { expect(subject.disabled?).to be_truthy }
    end
    context 'when widget is assigned to some dashboards' do
      it { expect(subject.disabled?).to be_falsey }
    end
    context 'when widget is running' do
      let(:widget_running) { true }
      it { expect(subject.disabled?).to be_truthy }
    end
    context 'when widget is not running' do
      it { expect(subject.disabled?).to be_falsey }
    end
  end
end
