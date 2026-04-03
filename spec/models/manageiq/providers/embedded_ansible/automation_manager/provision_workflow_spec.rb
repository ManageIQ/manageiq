describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ProvisionWorkflow do
  let(:admin) { FactoryBot.create(:user_with_group) }
  let(:manager) { FactoryBot.create(:provider_embedded_ansible, :default_organization => 1).managers.first }
  let(:workflow) { described_class.new({}, admin.userid) }

  before do
    EvmSpecHelper.assign_embedded_ansible_role
    MiqDialog.seed_dialog(Rails.root.join("product/dialogs/miq_dialogs/miq_provision_configuration_script_embedded_ansible_dialogs.yaml"))
  end

  describe "#allowed_configuration_scripts" do
    let!(:config_script1) { FactoryBot.create(:embedded_ansible_configuration_script, :manager => manager) }
    let!(:config_script2) { FactoryBot.create(:embedded_ansible_configuration_script, :manager => manager) }

    it "returns all configuration scripts" do
      scripts = workflow.allowed_configuration_scripts
      expect(scripts.count).to eq(2)
      expect(scripts.map { |s| s[:id] }).to match_array([config_script1.id, config_script2.id])
    end
  end

  describe "#allowed_machine_credentials" do
    let!(:machine_cred1) { FactoryBot.create(:embedded_ansible_machine_credential, :manager => manager) }
    let!(:machine_cred2) { FactoryBot.create(:embedded_ansible_machine_credential, :manager => manager) }

    it "returns all machine credentials" do
      credentials = workflow.allowed_machine_credentials
      expect(credentials).to be_a(Hash)
      expect(credentials.count).to eq(2)
      expect(credentials.keys).to match_array([machine_cred1.id, machine_cred2.id])
      expect(credentials.values).to match_array([machine_cred1.name, machine_cred2.name])
    end
  end

  describe "#allowed_vault_credentials" do
    let!(:vault_cred1) { FactoryBot.create(:embedded_ansible_vault_credential, :manager => manager) }
    let!(:vault_cred2) { FactoryBot.create(:embedded_ansible_vault_credential, :manager => manager) }

    it "returns all vault credentials" do
      credentials = workflow.allowed_vault_credentials
      expect(credentials).to be_a(Hash)
      expect(credentials.count).to eq(2)
      expect(credentials.keys).to match_array([vault_cred1.id, vault_cred2.id])
      expect(credentials.values).to match_array([vault_cred1.name, vault_cred2.name])
    end
  end

  describe "#allowed_cloud_credentials" do
    let!(:amazon_cred1) { FactoryBot.create(:embedded_ansible_amazon_credential, :manager => manager) }
    let!(:amazon_cred2) { FactoryBot.create(:embedded_ansible_amazon_credential, :manager => manager) }
    let!(:azure_cred)   { FactoryBot.create(:embedded_ansible_azure_credential,  :manager => manager) }

    it "returns all cloud credentials when no type is selected" do
      credentials = workflow.allowed_cloud_credentials

      expect(credentials).to be_a(Hash)
      expect(credentials.count).to eq(3)
      expect(credentials.keys).to match_array([amazon_cred1.id, amazon_cred2.id, azure_cred.id])
    end

    it "returns only credentials of the selected type" do
      workflow.instance_variable_set(:@values, {:cloud_credential_type => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AmazonCredential"})
      credentials = workflow.allowed_cloud_credentials

      expect(credentials).to be_a(Hash)
      expect(credentials.count).to eq(2)
      expect(credentials.keys).to match_array([amazon_cred1.id, amazon_cred2.id])
    end
  end

  describe "#allowed_cloud_credential_types" do
    let!(:amazon_cred) { FactoryBot.create(:embedded_ansible_amazon_credential, :manager => manager) }
    let!(:azure_cred)  { FactoryBot.create(:embedded_ansible_azure_credential,  :manager => manager) }

    it "returns all cloud credential types when no credential is selected" do
      types = workflow.allowed_cloud_credential_types

      expect(types).to be_a(Hash)
      expect(types.keys).to include(
        "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AmazonCredential",
        "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AzureCredential"
      )
    end

    it "returns only the selected credential type when a credential is selected" do
      workflow.instance_variable_set(:@values, {:cloud_credential_id => amazon_cred.id})
      types = workflow.allowed_cloud_credential_types

      expect(types).to be_a(Hash)
      expect(types.count).to eq(1)
      expect(types.keys).to include("ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AmazonCredential")
    end
  end
end
