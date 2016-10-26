describe ApplicationHelper::Button::MiqAeDomainEdit do
  let(:view_context) { setup_view_context_with_sandbox({}) }

  describe '#visible?' do
    context 'when domain locked' do
      it 'will not be skipped' do
        @record = FactoryGirl.create(:miq_ae_domain_disabled)
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_domain_edit'})
        expect(button.visible?).to be_truthy
      end
    end
  end
end
