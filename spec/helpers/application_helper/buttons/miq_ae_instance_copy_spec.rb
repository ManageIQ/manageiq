describe ApplicationHelper::Button::MiqAeInstanceCopy do
  let(:session) { Hash.new }
  let(:view_context) { setup_view_context_with_sandbox({}) }
  let(:method_record) do
    FactoryGirl.create(
      :miq_ae_method,
      :scope    => 'class',
      :language => 'ruby',
      :location => 'builtin',
      :ae_class => @record
    )
  end

  before do
    user = FactoryGirl.create(:user, :with_miq_edit_features)
    login_as user
    @record = FactoryGirl.create(:miq_ae_class, :of_domain, :domain => FactoryGirl.create(:miq_ae_domain_disabled))
  end

  describe '#visible?' do
    it 'will not be skipped when record is a class and domain is locked' do
      record = FactoryGirl.create(:miq_ae_domain_disabled)
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_instance_copy'})
      expect(button.visible?).to be_truthy
    end
    it 'will not be skipped when record is an instance and domain is locked' do
      button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_instance_copy'})
      expect(button.visible?).to be_truthy
    end
    it 'will not be skipped when button is miq_ae_method_copy and domain is locked' do
      button = described_class.new(view_context, {}, {'record' => method_record}, {:child_id => 'miq_ae_method_copy'})
      expect(button.visible?).to be_truthy
    end
  end

  describe '#disabled?' do
    it 'will be disabled when record is not editable' do
      allow(@record).to receive(:editable?).and_return(false)
      button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_instance_copy'})
      expect(button.disabled?).to be_truthy
    end
    it 'will be disabled when button is miq_ae_method_copy and domain is not editable' do
      button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_method_copy'})
      expect(button.visible?).to be_truthy
    end
  end
end
