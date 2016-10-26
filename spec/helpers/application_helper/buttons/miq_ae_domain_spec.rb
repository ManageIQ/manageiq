describe ApplicationHelper::Button::MiqAeDomain do
  let(:view_context) { setup_view_context_with_sandbox({}) }

  describe '#disabled?' do
    context 'when record has editable properties' do
      it 'will not be disabled' do
        @record = FactoryGirl.build(:miq_ae_domain_enabled)
        button = described_class.new(view_context, {}, {'record' => @record}, :child_id => 'miq_ae_domain_something')
        expect(button.disabled?).to be_falsey
      end
    end
    context 'when record has not editable properties' do
      it 'will be disabled' do
        @record = FactoryGirl.build(:miq_ae_system_domain)
        button = described_class.new(view_context, {}, {'record' => @record}, :child_id => 'miq_ae_domain_something')
        expect(button.disabled?).to be_truthy
      end
    end
  end
end
