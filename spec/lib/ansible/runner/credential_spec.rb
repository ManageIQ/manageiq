RSpec.describe Ansible::Runner::Credential do
  around do |example|
    Dir.mktmpdir("ansible-runner-credential-test") do |dir|
      @base_dir = dir
      example.run
    end
  end

  describe ".new" do
    it "initializes a GenericCredential when given a missing auth_type" do
      auth = FactoryBot.create(:authentication)
      cred = described_class.new(auth.id, @base_dir)
      expect(cred).to be_an_instance_of(Ansible::Runner::GenericCredential)
    end

    it "initializes a MachineCredential for ManageIQ::Providers::EmbeddedAnsible::AutomationManager::MachineCredentials" do
      auth = FactoryBot.create(:embedded_ansible_machine_credential)
      cred = described_class.new(auth.id, @base_dir)
      expect(cred).to be_an_instance_of(Ansible::Runner::MachineCredential)
    end

    it "initializes attributes" do
      auth = FactoryBot.create(:authentication)
      cred = described_class.new(auth.id, @base_dir)
      expect(cred.auth.id).to eq(auth.id)
      expect(cred.base_dir).to eq(@base_dir)
    end
  end
end
