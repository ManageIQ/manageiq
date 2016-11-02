describe ApplicationHelper::Button::MiqAeDomain do
  let(:view_context) { setup_view_context_with_sandbox({}) }

  describe '#disabled?' do
    it 'will not be disabled when record has editable properties' do
      record = FactoryGirl.build(:miq_ae_domain_enabled)
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_domain_something'})
      expect(button.disabled?).to be_falsey
    end
    it 'will be disabled when record has not editable properties' do
      record = FactoryGirl.build(:miq_ae_system_domain)
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_domain_something'})
      expect(button.disabled?).to be_truthy
    end
  end
end
