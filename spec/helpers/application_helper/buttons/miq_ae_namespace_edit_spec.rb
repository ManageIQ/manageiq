describe ApplicationHelper::Button::MiqAeNamespaceEdit do
  let(:session) { Hash.new }
  let(:view_context) { setup_view_context_with_sandbox({}) }

  before do
    Tenant.seed
    feature_list = %w(
      miq_ae_class_edit
      miq_ae_domain_edit
      miq_ae_class_copy
      miq_ae_instance_copy
      miq_ae_method_copy
      miq_ae_namespace_edit
    )
    user = FactoryGirl.create(:user, :features => feature_list)
    login_as user
  end

  describe '#visible?' do
    context 'when domain is unlocked' do
      it 'will not be skipped' do
        @record = FactoryGirl.create(:miq_ae_domain)
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_namespace_edit'})
        expect(button.visible?).to be_truthy
      end
    end
  end

  describe '#disabled?' do
    context 'when it is a system domain' do
      it 'will be disabled' do
        @record = FactoryGirl.build(:miq_ae_system_domain)
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_namespace_edit'})
        expect(button.disabled?).to be_truthy
      end
    end
  end
end
