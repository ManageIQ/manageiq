describe ApplicationHelper::Button::MiqAeClassCopy do
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
    @namespace = FactoryGirl.create(:miq_ae_namespace, :name => 'test_namespace', :parent => @domain)
    @record = FactoryGirl.create(:miq_ae_class, :name => 'test_class', :namespace_id => @namespace.id)
  end

  describe '#visible?' do
    context 'when there are no editable domains' do
      it 'will be skipped' do
        @domain.lock_contents!
        @domain.reload
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_class_copy'})
        expect(button.visible?).to be_falsey
      end
    end
    context 'when there are editable domains' do
      it 'will not be skipped' do
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_class_copy'})
        expect(button.visible?).to be_truthy
      end
    end
  end
end
