describe ApplicationHelper::Button::MiqAeGitRefresh do
  let(:view_context) { setup_view_context_with_sandbox({}) }

  before do
    MiqRegion.seed
    @record = FactoryGirl.create(:miq_ae_git_domain)
  end

  describe '#visible?' do
    it 'will be skipped when git not enabled' do
      button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_git_refresh'})
      allow(@record).to receive(:git_enabled?).and_return(false)
      allow(MiqRegion.my_region).to receive(:role_active?).with('git_owner').and_return(true)
      expect(button.visible?).to be_falsey
    end
    it 'will be skipped when GitBasedDomainImportService not available' do
      button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_git_refresh'})
      allow(MiqRegion.my_region).to receive(:role_active?).with('git_owner').and_return(false)
      expect(button.visible?).to be_falsey
    end
    it 'will not be skipped when git enabled and GitBasedDomainImportService available' do
      button = described_class.new(view_context, {}, {'record' => @record}, {:child_id => 'miq_ae_git_refresh'})
      allow(MiqRegion.my_region).to receive(:role_active?).with('git_owner').and_return(true)
      expect(button.visible?).to be_truthy
    end
  end
end
