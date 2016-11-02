describe ApplicationHelper::Button::MiqAeDomainUnlock do
  let(:view_context) { setup_view_context_with_sandbox({}) }

  describe '#visible?' do
    it 'will be skipped when domain not locked by user' do
      record = FactoryGirl.create(:miq_ae_domain)
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_domain_unlock'})
      expect(button.visible?).to be_falsey
    end
    it 'will not be skipped when domain locked by user' do
      record = FactoryGirl.create(:miq_ae_domain_user_locked)
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_domain_unlock'})
      expect(button.visible?).to be_truthy
    end
  end
end
