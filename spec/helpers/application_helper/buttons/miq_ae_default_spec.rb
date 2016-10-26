describe ApplicationHelper::Button::MiqAeDefault do
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

  before(:each) do
    @domain = FactoryGirl.create(:miq_ae_domain)
    @namespace = FactoryGirl.create(:miq_ae_namespace, :name => 'test_namespace', :parent => @domain)
    @record = FactoryGirl.create(:miq_ae_class, :name => 'test_class', :namespace_id => @namespace.id)
  end

  describe '#visible?' do
    context 'when button does not copy and domains are not editable' do
      it 'will be skipped' do
        @domain.lock_contents!
        @domain.reload
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_class_edit'})
        expect(button.visible?).to be_falsey
      end
    end
    context 'when button does not copy but domains are editable' do
      it 'will not be skipped' do
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_class_edit'})
        expect(button.visible?).to be_truthy
      end
    end
    context 'when user has view access only' do
      it 'will be skipped' do
        login_as FactoryGirl.create(:user, :features => 'miq_ae_domain_view')
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_class_edit'})
        expect(button.skipped?).to be_truthy
      end
    end
  end

  describe '#disabled?' do
    context 'when domains are not editable and not available for copy' do
      it 'will not be disabled' do
        @domain.lock_contents!
        @domain.reload
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_class_edit'})
        expect(button.disabled?).to be_falsey
      end
    end
  end
end
