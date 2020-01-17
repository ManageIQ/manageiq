RSpec.describe ManageIQ::Providers::EmbeddedAnsible do
  describe ".seed" do
    let(:provider) { ManageIQ::Providers::EmbeddedAnsible::Provider.first }
    let(:manager)  { provider.automation_manager }

    let(:consolidated_repo_path) { Ansible::Content::PLUGIN_CONTENT_DIR }
    let(:manager_repo_path)      { GitRepository::GIT_REPO_DIRECTORY }

    before do
      EvmSpecHelper.local_miq_server
      described_class.seed
    end

    after do
      FileUtils.rm_rf(Dir.glob(File.join(manager_repo_path, "*")))
      FileUtils.rm_rf(Dir.glob(File.join(consolidated_repo_path, "*")))
    end

    it "creates a provider with a manager" do
      expect(provider.name).to eq("Embedded Ansible")
      expect(manager.name).to eq("Embedded Ansible")
      expect(manager.zone.id).to eq(MiqServer.my_server.zone.id)
    end

    it "creates the default authentication" do
      auth = manager.authentications.find_by(:name => "ManageIQ Default Credential")
      expect(auth).to be_an_instance_of(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::MachineCredential)
      expect(auth.manager_ref).to eq(auth.id.to_s)
    end

    it "consolidates the embedded ansible content" do
      expect(Dir.exist?(File.join(consolidated_repo_path))).to be_truthy
    end
  end
end
