require 'ansible/runner'
require 'ansible/runner/credential'

RSpec.describe Ansible::Runner::GoogleCredential do
  it ".auth_type is the correct Authentication sub-class" do
    expect(described_class.auth_type).to eq("ManageIQ::Providers::EmbeddedAnsible::AutomationManager::GoogleCredential")
  end

  context "with a credential object" do
    around do |example|
      Dir.mktmpdir("ansible-runner-credential-test") do |dir|
        @base_dir = dir
        example.run
      end
    end

    let(:auth) { FactoryBot.create(:embedded_ansible_google_credential, auth_attributes) }
    let(:auth_attributes) do
      {
        :userid   => "manageiq@gmail.com",
        :auth_key => "key_data",
        :options  => { :project => "google_project" }
      }
    end

    let(:cred) { described_class.new(auth.id, @base_dir) }

    describe "#command_line" do
      it "returns an empty hash" do
        expect(cred.command_line).to eq({})
      end
    end

    # Modeled off of gce injectors for awx:
    #
    #   https://github.com/ansible/awx/blob/1242ee2b/awx/main/models/credential/injectors.py#L11-L15
    #
    describe "#env_vars" do
      it "sets GCE_EMAIL, GCE_PROJECT, and GCE_CREDENTIALS_FILE_PATH" do
        filename = File.join(@base_dir, "gce_credentials")
        expected = {
          "GCE_EMAIL"                 => "manageiq@gmail.com",
          "GCE_PROJECT"               => "google_project",
          "GCE_CREDENTIALS_FILE_PATH" => filename
        }
        expect(cred.env_vars).to eq(expected)
      end

      it "defaults GCE_EMAIL and GCE_PROJECT to '' if missing" do
        filename = File.join(@base_dir, "gce_credentials")
        auth.update!(:userid => nil, :options => nil)

        expected = {
          "GCE_EMAIL"                 => "",
          "GCE_PROJECT"               => "",
          "GCE_CREDENTIALS_FILE_PATH" => filename
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
      it "writes the the env/gce_credentials to a file" do
        cred.write_config_files

        actual_data   = JSON.parse(File.read(File.join(@base_dir, "gce_credentials")))
        expected_data = {
          "type"         => "service_account",
          "private_key"  => "key_data",
          "client_email" => "manageiq@gmail.com",
          "project_id"   => "google_project",
        }

        expect(expected_data).to eq(actual_data)
      end

      it "files in empty data with emtpy strings (matching awx implementation)" do
        auth.update!(:auth_key => nil, :userid => nil, :options => nil)
        cred.write_config_files

        actual_data   = JSON.parse(File.read(File.join(@base_dir, "gce_credentials")))
        expected_data = {
          "type"         => "service_account",
          "private_key"  => "",
          "client_email" => "",
          "project_id"   => "",
        }

        expect(expected_data).to eq(actual_data)
      end

      it "handles empty options hash" do
        auth.update!(:options => {})
        cred.write_config_files

        actual_data   = JSON.parse(File.read(File.join(@base_dir, "gce_credentials")))
        expected_data = {
          "type"         => "service_account",
          "private_key"  => "key_data",
          "client_email" => "manageiq@gmail.com",
          "project_id"   => "",
        }

        expect(expected_data).to eq(actual_data)
      end
    end
  end
end
