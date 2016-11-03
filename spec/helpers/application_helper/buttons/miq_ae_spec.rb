describe ApplicationHelper::Button::MiqAe do
  let(:session) { Hash.new }
  let(:view_context) { setup_view_context_with_sandbox({}) }
  subject { described_class.new(view_context, {}, {'record' => record}, {:child_id => child_id}) }

  before { login_as FactoryGirl.create(:user, :with_miq_edit_features) }

  describe '#visible?' do
    context 'when button does not copy' do
      let(:child_id) { 'miq_ae_domain_edit' }
      let(:record) { FactoryGirl.build(:miq_ae_domain_enabled) }
      it { expect(subject.visible?).to be_falsey }
    end
    context do
      let(:child_id) { 'miq_ae_class_copy' }
      context 'when editable domains not available' do
        let(:record) { FactoryGirl.build(:miq_ae_domain_disabled) }
        it { expect(subject.visible?).to be_falsey }
      end
      context 'when editable domains available' do
        let(:record) { FactoryGirl.create(:miq_ae_class, :of_domain, :domain => FactoryGirl.create(:miq_ae_domain)) }
        it { expect(subject.visible?).to be_truthy }
      end
    end
  end

  describe '#disabled?' do
    context 'when domains not editable' do
      let(:child_id) { 'miq_ae_domain_edit' }
      let(:record) { FactoryGirl.build(:miq_ae_domain_disabled) }
      it { expect(subject.disabled?).to be_falsey }
    end
    context 'when domains not available for copy but editable' do
      let(:child_id) { 'miq_ae_domain_copy' }
      let(:record) { FactoryGirl.build(:miq_ae_domain_enabled) }
      it { expect(subject.disabled?).to be_falsey }
    end
    context 'when domains are not editable and not available for copy' do
      let(:child_id) { 'miq_ae_domain_edit' }
      let(:record) { FactoryGirl.build(:miq_ae_system_domain) }
      it { expect(subject.disabled?).to be_truthy }
    end
  end
end
