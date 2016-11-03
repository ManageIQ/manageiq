describe ApplicationHelper::Button::MiqAeDomainPriorityEdit do
  let(:session) { Hash.new }
  let(:view_context) { setup_view_context_with_sandbox({}) }
  subject { described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_domain_priority_edit'}) }

  before { login_as FactoryGirl.create(:user, :with_miq_edit_features) }

  describe '#disabled?' do
    let(:record) { FactoryGirl.create(:miq_ae_domain) }
    before { allow(User).to receive(:current_tenant).and_return(Tenant.first) }

    context 'when number of visible domains < 2' do
      before { allow(User.current_tenant).to receive(:visible_domains).and_return([record]) }
      it { expect(subject.disabled?).to be_truthy }
    end
    context 'when number of visible domains >= 2' do
      before { allow(User.current_tenant).to receive(:visible_domains).and_return([record, record]) }
      it { expect(subject.disabled?).to be_falsey }
    end
  end
end
