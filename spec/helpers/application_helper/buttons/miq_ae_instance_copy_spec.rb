describe ApplicationHelper::Button::MiqAeInstanceCopy do
  let(:session) { Hash.new }
  let(:view_context) { setup_view_context_with_sandbox({}) }
  let(:record) { FactoryGirl.create(:miq_ae_class, :of_domain, :domain => domain) }
  let(:domain) { FactoryGirl.create(:miq_ae_domain_disabled) }
  subject { described_class.new(view_context, {}, {'record' => record}, {:child_id => child_id}) }

  before { login_as FactoryGirl.create(:user, :with_miq_edit_features) }

  describe '#visible?' do
    context 'when domain is locked' do
      context 'and button is miq_ae_instance_copy' do
        let(:child_id) { 'miq_ae_instance_copy' }
        context 'with record as domain' do
          let(:record) { domain }
          it { expect(subject.visible?).to be_truthy }
        end
        context 'with record as class of locked domain' do
          it { expect(subject.visible?).to be_truthy }
        end
      end
      context 'and button is miq_ae_method_copy with method record' do
        let(:child_id) { 'miq_ae_method_copy' }
        let(:klass) { FactoryGirl.create(:miq_ae_class, :of_domain, :domain => domain) }
        let(:record) do
          FactoryGirl.create(:miq_ae_method, :scope => 'class', :language => 'ruby',
                                          :location => 'builtin', :ae_class => klass)
        end
        it { expect(subject.visible?).to be_truthy }
      end
    end
  end

  describe '#disabled?' do
    context 'when record is a class of a locked domain' do
      context 'and button is miq_ae_instance_copy with an editable record' do
        let(:child_id) { 'miq_ae_instance_copy' }
        before { allow(record).to receive(:editable?).and_return(false) }
        it { expect(subject.disabled?).to be_truthy }
      end
      context 'and button is miq_ae_method_copy' do
        let(:child_id) { 'miq_ae_method_copy' }
        it { expect(subject.visible?).to be_truthy }
      end
    end
  end
end
