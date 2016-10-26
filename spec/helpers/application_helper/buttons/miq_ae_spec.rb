describe ApplicationHelper::Button::MiqAe do
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
    context 'when button does not copy' do
      it 'will be skipped' do
        @record = FactoryGirl.build(:miq_ae_domain_enabled)
        button = described_class.new(view_context, {}, {'record' => @record}, :child_id => 'miq_ae_domain_edit')
        expect(button.visible?).to be_falsey
      end
    end
    context 'when editable domains not available' do
      it 'will be skipped' do
        @record = FactoryGirl.build(:miq_ae_domain_disabled)
        button = described_class.new(view_context, {}, {'record' => @record}, :child_id => 'miq_ae_class_copy')
        expect(button.visible?).to be_falsey
      end
    end
    context 'when editable domains available' do
      it 'will not be skipped' do
        @domain = FactoryGirl.create(:miq_ae_domain)
        @namespace = FactoryGirl.create(:miq_ae_namespace, :name => 'test_namespace', :parent => @domain)
        @record = FactoryGirl.create(:miq_ae_class, :name => 'test_class', :namespace_id => @namespace.id)
        button = described_class.new(view_context, {}, {'record' => @record}, :child_id => 'miq_ae_class_copy')
        expect(button.visible?).to be_truthy
      end
    end
  end

  describe '#disabled?' do
    context 'when domains not editable' do
      it 'will not be disabled' do
        @record = FactoryGirl.build(:miq_ae_domain_disabled)
        button = described_class.new(view_context, {}, {'record' => @record}, :child_id => 'miq_ae_domain_edit')
        expect(button.disabled?).to be_falsey
      end
    end
    context 'when domains not available for copy but editable' do
      it 'will not be disabled' do
        @record = FactoryGirl.build(:miq_ae_domain_enabled)
        button = described_class.new(view_context, {}, {'record' => @record}, :child_id => 'miq_ae_domain_copy')
        expect(button.disabled?).to be_falsey
      end
    end
    context 'when domains are not editable and not available for copy' do
      it 'will be disabled' do
        @record = FactoryGirl.build(:miq_ae_system_domain)
        button = described_class.new(view_context, {}, {'record' => @record}, :child_id => 'miq_ae_domain_edit')
        expect(button.disabled?).to be_truthy
      end
    end
  end
end
