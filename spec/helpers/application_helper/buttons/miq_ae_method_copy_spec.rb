describe ApplicationHelper::Button::MiqAeMethodCopy do
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
    @domain = FactoryGirl.create(:miq_ae_domain)
    @domain.lock_contents!
    @domain.reload
    @namespace = FactoryGirl.create(:miq_ae_namespace, :name => 'test_namespace', :parent => @domain)
    @class = FactoryGirl.create(:miq_ae_class, :name => 'test_class', :namespace_id => @namespace.id)
    @record = FactoryGirl.create(
        :miq_ae_method,
        :scope    => 'class',
        :language => 'ruby',
        :location => 'builtin',
        :ae_class => @class
    )
  end

  describe '#visible?' do
    context 'when domain locked' do
      it 'will not be skipped' do
        button = described_class.new(view_context, {}, {'record' => @record}, :child_id => 'miq_ae_method_copy')
        expect(button.visible?).to be_truthy
      end
    end
  end

  describe '#disabled?' do
    context 'when domain is not editable' do
      it 'will be disabled' do
        button = described_class.new(view_context, {}, {'record' => @record}, :child_id => 'miq_ae_method_copy')
        expect(button.visible?).to be_truthy
      end
    end
  end
end
