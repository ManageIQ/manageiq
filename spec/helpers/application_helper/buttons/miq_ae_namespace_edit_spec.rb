describe ApplicationHelper::Button::MiqAeNamespaceEdit do
  let(:session) { Hash.new }
  let(:view_context) { setup_view_context_with_sandbox({}) }

  before do
    user = FactoryGirl.create(:user, :with_miq_edit_features)
    login_as user
  end

  describe '#visible?' do
    it 'will not be skipped when domain is unlocked' do
      record = FactoryGirl.create(:miq_ae_domain)
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_namespace_edit'})
      expect(button.visible?).to be_truthy
    end
  end

  describe '#disabled?' do
    it 'will be disabled when it is a system domain' do
      record = FactoryGirl.build(:miq_ae_system_domain)
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_namespace_edit'})
      expect(button.disabled?).to be_truthy
    end
  end
end
