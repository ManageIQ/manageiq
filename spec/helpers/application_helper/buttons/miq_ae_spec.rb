describe ApplicationHelper::Button::MiqAe do
  let(:session) { Hash.new }
  let(:view_context) { setup_view_context_with_sandbox({}) }

  before do
    user = FactoryGirl.create(:user, :with_miq_edit_features)
    login_as user
  end

  describe '#visible?' do
    it 'will be skipped when button does not copy' do
      record = FactoryGirl.build(:miq_ae_domain_enabled)
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_domain_edit'})
      expect(button.visible?).to be_falsey
    end
    it 'will be skipped when editable domains not available' do
      record = FactoryGirl.build(:miq_ae_domain_disabled)
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_class_copy'})
      expect(button.visible?).to be_falsey
    end
    it 'will not be skipped when editable domains available' do
      record = FactoryGirl.create(:miq_ae_class, :of_domain, :domain => FactoryGirl.create(:miq_ae_domain))
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_class_copy'})
      expect(button.visible?).to be_truthy
    end
  end

  describe '#disabled?' do
    it 'will not be disabled when domains not editable' do
      record = FactoryGirl.build(:miq_ae_domain_disabled)
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_domain_edit'})
      expect(button.disabled?).to be_falsey
    end
    it 'will not be disabled when domains not available for copy but editable' do
      record = FactoryGirl.build(:miq_ae_domain_enabled)
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_domain_copy'})
      expect(button.disabled?).to be_falsey
    end
    it 'will be disabled when domains are not editable and not available for copy' do
      record = FactoryGirl.build(:miq_ae_system_domain)
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_domain_edit'})
      expect(button.disabled?).to be_truthy
    end
  end
end
