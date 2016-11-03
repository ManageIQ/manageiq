describe ApplicationHelper::Button::MiqAeGitRefresh do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  let(:record) { FactoryGirl.create(:miq_ae_git_domain) }
  subject { described_class.new(view_context, {}, {'record' => record}, {:child_id => 'miq_ae_git_refresh'}) }

  before { MiqRegion.seed }

  describe '#visible?' do
    context 'when git not enabled' do
      before do
        allow(record).to receive(:git_enabled?).and_return(false)
        allow(MiqRegion.my_region).to receive(:role_active?).with('git_owner').and_return(true)
      end
      it { expect(subject.visible?).to be_falsey }
    end
    context 'when GitBasedDomainImportService not available' do
      before { allow(MiqRegion.my_region).to receive(:role_active?).with('git_owner').and_return(false) }
      it { expect(subject.visible?).to be_falsey }
    end
    context 'when git enabled and GitBasedDomainImportService available' do
      before { allow(MiqRegion.my_region).to receive(:role_active?).with('git_owner').and_return(true) }
      it { expect(subject.visible?).to be_truthy }
    end
  end
end
