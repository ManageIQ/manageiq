describe ApplicationHelper::Button::MiqAeDomainEdit do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  subject { described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_domain_edit'}) }

  describe '#visible?' do
    context 'when domain is locked' do
      let(:record) { FactoryGirl.create(:miq_ae_domain_disabled) }
      it { expect(subject.visible?).to be_truthy }
    end
  end
end
