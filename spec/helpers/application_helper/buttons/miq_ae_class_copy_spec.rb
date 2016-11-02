describe ApplicationHelper::Button::MiqAeClassCopy do
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
    it 'will be skipped when there are no editable domains' do
      button = described_class.new(view_context, {}, {'record' => record_with_locked_domain},
                                   {:child_id => 'miq_ae_class_copy'})
      expect(button.visible?).to be_falsey
    end
    it 'will not be skipped when there are editable domains' do
      button = described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_class_copy'})
      expect(button.visible?).to be_truthy
    end
  end
end
