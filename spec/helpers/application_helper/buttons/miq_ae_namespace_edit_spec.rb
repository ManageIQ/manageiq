describe ApplicationHelper::Button::MiqAeNamespaceEdit do
  let(:session) { Hash.new }
  let(:view_context) { setup_view_context_with_sandbox({}) }
  subject { described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_namespace_edit'}) }

  before { login_as FactoryGirl.create(:user, :with_miq_edit_features) }

  describe '#visible?' do
    context 'when domain is unlocked' do
      let(:record) { FactoryGirl.create(:miq_ae_domain) }
      it { expect(subject.visible?).to be_truthy }
    end
    context 'when record is a namespace with user domain' do
      let(:record) { FactoryGirl.create(:miq_ae_namespace, :parent => FactoryGirl.create(:miq_ae_domain)) }
      it { expect(subject.visible?).to be_truthy }
    end
    context 'when record is a namespace with user locked domain' do
      let(:record) { FactoryGirl.create(:miq_ae_namespace, :parent => FactoryGirl.create(:miq_ae_domain_user_locked)) }
      it { expect(subject.visible?).to be_falsey }
    end
  end

  describe '#disabled?' do
    context 'when record is a system domain' do
      let(:record) { FactoryGirl.create(:miq_ae_system_domain) }
      it { expect(subject.disabled?).to be_truthy }
    end
    context 'when record is a namespace domain of an editable domain' do
      let(:record) { FactoryGirl.create(:miq_ae_namespace, :parent => FactoryGirl.create(:miq_ae_domain)) }
      it { expect(subject.disabled?).to be_falsey }
    end
    context 'when record is a namespace domain of an uneditable domain' do
      let(:record) { FactoryGirl.create(:miq_ae_namespace, :parent => FactoryGirl.create(:miq_ae_system_domain)) }
      it { expect(subject.disabled?).to be_truthy }
    end
  end
end
