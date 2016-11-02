describe ApplicationHelper::Button::MiqAeDomainPriorityEdit do
  let(:view_context) { setup_view_context_with_sandbox({}) }

  before { @record = FactoryGirl.create(:miq_ae_domain) }

  describe '#disabled?' do
    it 'will be disabled when number of visible domains < 2' do
      button = described_class.new(view_context, {}, {'record' => @record},
                                   {:child_id => 'miq_ae_domain_priority_edit'})
      allow(User).to receive(:current_tenant).and_return(Tenant.first)
      allow(User.current_tenant).to receive(:visible_domains).and_return([@record])
      expect(button.disabled?).to be_truthy
    end
    it 'will not be disabled when number of visible domains >= 2' do
      button = described_class.new(view_context, {}, {'record' => @record},
                                   {:child_id => 'miq_ae_domain_priority_edit'})
      allow(User).to receive(:current_tenant).and_return(Tenant.first)
      allow(User.current_tenant).to receive(:visible_domains).and_return([@record, @record])
      expect(button.disabled?).to be_falsey
    end
  end
end
