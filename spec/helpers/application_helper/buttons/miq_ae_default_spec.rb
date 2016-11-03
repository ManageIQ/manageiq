describe ApplicationHelper::Button::MiqAeDefault do
  let(:session) { Hash.new }
  let(:view_context) { setup_view_context_with_sandbox({}) }
  let(:record) { FactoryGirl.create(:miq_ae_class, :of_domain, :domain => domain) }
  let(:subject) { described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_class_edit'}) }

  before { login_as FactoryGirl.create(:user, :with_miq_edit_features) }

  describe '#visible?' do
    context 'when button does not copy and domains are not editable' do
      let(:domain) { FactoryGirl.create(:miq_ae_domain_user_locked) }
      it { expect(subject.visible?).to be_falsey }
    end
    context 'when button does not copy but domains are editable' do
      let(:domain) { FactoryGirl.create(:miq_ae_domain) }
      it { expect(subject.visible?).to be_truthy }
    end
    context 'when user has view access only' do
      let(:domain) { FactoryGirl.create(:miq_ae_domain) }
      before { login_as FactoryGirl.create(:user, :features => 'miq_ae_domain_view') }
      it { expect(subject.skipped?).to be_truthy }
    end
  end

  describe '#disabled?' do
    context 'when domains are not editable and not available for copy' do
      let(:domain) { FactoryGirl.create(:miq_ae_domain_user_locked) }
      it { expect(subject.disabled?).to be_falsey }
    end
  end
end
