require 'ansible/runner'
require 'ansible/runner/credential'

RSpec.describe Ansible::Runner::VaultCredential do
  it ".auth_type is the correct Authentication sub-class" do
    expect(described_class.auth_type).to eq("ManageIQ::Providers::EmbeddedAnsible::AutomationManager::VaultCredential")
  end

  context "with a credential object" do
    around do |example|
      Dir.mktmpdir("ansible-runner-credential-test") do |dir|
        @base_dir = dir
        example.run
      end
    end

    let(:auth)            { FactoryBot.create(:embedded_ansible_vault_credential, auth_attributes) }
    let(:cred)            { described_class.new(auth.id, @base_dir) }
    let(:auth_attributes) { { :password => "vault_secret" } }
    let(:vault_filename)  { File.join(@base_dir, "vault_password") }

    describe "#command_line" do
      it "returns an empty hash" do
        expect(cred.command_line).to eq({})
      end
    end

    describe "#env_vars" do
      context "with a password" do
        it "passes --vault-password-file" do
          expected = { "ANSIBLE_VAULT_PASSWORD_FILE" => vault_filename }
          expect(cred.env_vars).to eq(expected)
        end
      end

      context "without a password" do
        it "passes --vault-password-file" do
          auth.update!(:password => nil)
          expect(cred.env_vars).to eq({})
        end
      end
    end

    describe "#extra_vars" do
      it "returns an empty hash" do
        expect(cred.extra_vars).to eq({})
      end
    end

    describe "#write_config_files" do
      context "with a password" do
        before { cred.write_config_files }

        it "writes the vault password file with the password" do
          expect(File.read(vault_filename)).to eq("vault_secret")
        end

        it "sets the permission to 400" do
          expect(File.stat(vault_filename).mode).to eq(0o100400)
        end
      end

      context "without a password" do
        it "does nothing" do
          auth.update!(:password => nil)
          cred.write_config_files

          expect(File.exist?(vault_filename)).to be_falsey
        end
      end
    end
  end
end
