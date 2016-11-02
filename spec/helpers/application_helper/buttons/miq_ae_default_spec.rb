describe ApplicationHelper::Button::MiqAeDefault do
  let(:session) { Hash.new }
  let(:view_context) { setup_view_context_with_sandbox({}) }
  let(:record) do
    FactoryGirl.create(:miq_ae_class, :of_domain, :domain => FactoryGirl.create(:miq_ae_domain))
  end
  let(:record_with_locked_domain) do
    FactoryGirl.create(:miq_ae_class, :of_domain, :domain => FactoryGirl.create(:miq_ae_domain_user_locked))
  end

  before do
    user = FactoryGirl.create(:user, :with_miq_edit_features)
    login_as user
  end

  describe '#visible?' do
    it 'will be skipped when button does not copy and domains are not editable' do
      button = described_class.new(view_context, {}, {'record' => record_with_locked_domain},
                                   {:child_id => 'miq_ae_class_edit'})
      expect(button.visible?).to be_falsey
    end
    it 'will not be skipped when button does not copy but domains are editable' do
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_class_edit'})
      expect(button.visible?).to be_truthy
    end
    it 'will be skipped when user has view access only' do
      login_as FactoryGirl.create(:user, :features => 'miq_ae_domain_view')
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_class_edit'})
      expect(button.skipped?).to be_truthy
    end
  end

  describe '#disabled?' do
    it 'will not be disabled when domains are not editable and not available for copy' do
      button = described_class.new(view_context, {}, {'record' => record_with_locked_domain},
                                   {:child_id => 'miq_ae_class_edit'})
      expect(button.disabled?).to be_falsey
    end
  end
end
