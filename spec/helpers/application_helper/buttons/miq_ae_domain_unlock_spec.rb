describe ApplicationHelper::Button::MiqAeDomainUnlock do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  subject { described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_domain_unlock'}) }

  describe '#visible?' do
    context 'when domain not locked by user' do
      let(:record) { FactoryGirl.create(:miq_ae_domain) }
      it { expect(subject.visible?).to be_falsey }
    end
    context 'when domain locked by user' do
      let(:record) { FactoryGirl.create(:miq_ae_domain_user_locked) }
      it { expect(subject.visible?).to be_truthy }
    end
  end
end
