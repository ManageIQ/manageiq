describe ApplicationHelper::Button::MiqAeClassCopy do
  let(:session) { Hash.new }
  let(:view_context) { setup_view_context_with_sandbox({}) }
  subject { described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_class_copy'}) }

  before { login_as FactoryGirl.create(:user, :with_miq_edit_features) }

  describe '#visible?' do
    let(:record) { FactoryGirl.create(:miq_ae_class, :of_domain, :domain => domain) }
    context 'when there are no editable domains' do
      let(:domain) { FactoryGirl.create(:miq_ae_domain_user_locked) }
      it { expect(subject.visible?).to be_falsey }
    end
    context 'when there are editable domains' do
      let(:domain) { FactoryGirl.create(:miq_ae_domain) }
      it { expect(subject.visible?).to be_truthy }
    end
  end
end
