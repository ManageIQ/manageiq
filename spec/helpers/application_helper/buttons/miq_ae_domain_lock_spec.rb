describe ApplicationHelper::Button::MiqAeDomainLock do
  let(:view_context) { setup_view_context_with_sandbox({}) }

  describe '#visible?' do
    context 'when domain locked by user' do
      it 'will be skipped' do
        @record = FactoryGirl.create(:miq_ae_domain_user_locked)
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_domain_lock'})
        expect(button.visible?).to be_falsey
      end
    end
    context 'when domain lockable but edit not possible' do
      it 'will not be skipped' do
        @record = FactoryGirl.create(:miq_ae_domain)
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_domain_lock'})
        expect(button.visible?).to be_truthy
      end
    end
  end
end
