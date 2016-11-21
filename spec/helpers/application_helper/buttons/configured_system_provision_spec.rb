describe ApplicationHelper::Button::ConfiguredSystemProvision do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  subject { described_class.new(view_context, {}, {'record' => record}, {}) }

  describe '#visible?' do
    context 'when record is present' do
      context 'and record cannot be provisionable' do
        let(:record) { FactoryGirl.create(:configuration_profile_foreman) }
        it { expect(subject.visible?).to be_truthy }
      end
      context 'and record is provisionable' do
        let(:record) { FactoryGirl.create(:configured_system_foreman) }
        it { expect(subject.visible?).to be_truthy }
      end
      context 'and record is not provisionable' do
        let(:record) { FactoryGirl.create(:configured_system_ansible_tower) }
        it { expect(subject.visible?).to be_falsey }
      end
    end
    context 'when record is not present' do
      let(:record) { nil }
      it { expect(subject.visible?).to be_truthy }
    end
  end
end
