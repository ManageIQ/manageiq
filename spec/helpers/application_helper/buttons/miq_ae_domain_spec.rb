describe ApplicationHelper::Button::MiqAeDomain do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  subject { described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_domain_something'}) }

  describe '#disabled?' do
    context 'when record has editable properties' do
      let(:record) { FactoryGirl.build(:miq_ae_domain_enabled) }
      it { expect(subject.disabled?).to be_falsey }
    end
    context 'when record has not editable properties' do
      let(:record) { FactoryGirl.build(:miq_ae_system_domain) }
      it { expect(subject.disabled?).to be_truthy }
    end
  end
end
