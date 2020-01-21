require 'ansible/runner'
require 'ansible/runner/credential'

RSpec.describe Ansible::Runner::VmwareCredential do
  it ".auth_type is the correct Authentication sub-class" do
    expect(described_class.auth_type).to eq("ManageIQ::Providers::EmbeddedAnsible::AutomationManager::VmwareCredential")
  end

  context "with a credential object" do
    around do |example|
      Dir.mktmpdir("ansible-runner-credential-test") do |dir|
        @base_dir = dir
        example.run
      end
    end

    let(:auth) { FactoryBot.create(:embedded_ansible_vmware_credential, auth_attributes) }
    let(:auth_attributes) do
      {
        :userid   => "manageiq-vmware",
        :password => "vmware_secret",
        :options  => {
          :host => "vmware_host"
        }
      }
    end

    let(:cred) { described_class.new(auth.id, @base_dir) }

    describe "#command_line" do
      it "returns an empty hash" do
        expect(cred.command_line).to eq({})
      end
    end

    # Modeled off of vmware injectors for awx:
    #
    #   https://github.com/ansible/awx/blob/1242ee2b/awx/main/models/credential/injectors.py#L63-L67
    #
    describe "#env_vars" do
      it "sets VMWARE_USER, VMWARE_PASSWORD, and VMWARE_HOST" do
        expected = {
          "VMWARE_USER"     => "manageiq-vmware",
          "VMWARE_PASSWORD" => "vmware_secret",
          "VMWARE_HOST"     => "vmware_host"
        }
        expect(cred.env_vars).to eq(expected)
      end

      it "defaults VMWARE_USER, VMWARE_PASSWORD, and VMWARE_HOST to '' if missing" do
        auth.update!(:userid => nil, :password => nil, :options => nil)
        expected = {
          "VMWARE_USER"     => "",
          "VMWARE_PASSWORD" => "",
          "VMWARE_HOST"     => ""
        }
        expect(cred.env_vars).to eq(expected)
      end

      it "handles empty options hash" do
        auth.update!(:options => {})
        expected = {
          "VMWARE_USER"     => "manageiq-vmware",
          "VMWARE_PASSWORD" => "vmware_secret",
          "VMWARE_HOST"     => ""
        }
        expect(cred.env_vars).to eq(expected)
      end
    end

    describe "#extra_vars" do
      it "returns an empty hash" do
        expect(cred.extra_vars).to eq({})
      end
    end

    describe "#write_config_files" do
      it "no-ops" do
        expect(cred.write_config_files).to be_nil
      end
    end
  end
end
