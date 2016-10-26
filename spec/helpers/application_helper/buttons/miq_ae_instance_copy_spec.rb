describe ApplicationHelper::Button::MiqAeInstanceCopy do
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
    @domain = FactoryGirl.create(:miq_ae_domain_disabled)
    @namespace = FactoryGirl.create(:miq_ae_namespace, :name => 'test_namespace', :parent => @domain)
    @record = FactoryGirl.create(:miq_ae_class, :name => 'test_class', :namespace_id => @namespace.id)
  end

  describe '#visible?' do
    context 'when record is a class and domain is locked' do
      it 'will not be skipped' do
        @record = FactoryGirl.create(:miq_ae_domain_disabled)
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_instance_copy'})
        expect(button.visible?).to be_truthy
      end
    end
    context 'when record is an instance and domain is locked' do
      it 'will not be skipped' do
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_instance_copy'})
        expect(button.visible?).to be_truthy
      end
    end
    context 'when button is miq_ae_method_copy and domain is locked' do
      it 'will not be skipped' do
        klass = @record
        @record = FactoryGirl.create(
          :miq_ae_method,
          :scope    => 'class',
          :language => 'ruby',
          :location => 'builtin',
          :ae_class => klass
        )
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_method_copy'})
        expect(button.visible?).to be_truthy
      end
    end
  end

  describe '#disabled?' do
    context 'when record is not editable' do
      it 'will be disabled' do
        allow(@record).to receive(:editable?).and_return(false)
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_instance_copy'})
        expect(button.disabled?).to be_truthy
      end
    end
    context 'when button is miq_ae_method_copy and domain is not editable' do
      it 'will be disabled' do
        button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_method_copy'})
        expect(button.visible?).to be_truthy
      end
    end
  end
end
