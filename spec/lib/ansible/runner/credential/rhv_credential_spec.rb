require 'ansible/runner'
require 'ansible/runner/credential'

RSpec.describe Ansible::Runner::RhvCredential do
  it ".auth_type is the correct Authentication sub-class" do
    expect(described_class.auth_type).to eq("ManageIQ::Providers::EmbeddedAnsible::AutomationManager::RhvCredential")
  end

  context "with a credential object" do
    around do |example|
      Dir.mktmpdir("ansible-runner-credential-test") do |dir|
        @base_dir = dir
        example.run
      end
    end

    let(:auth) { FactoryBot.create(:embedded_ansible_rhv_credential, auth_attributes) }
    let(:auth_attributes) do
      {
        :userid   => "manageiq-rhv",
        :password => "rhv_password",
        :options  => { :host => "rhv_host" }
      }
    end

    let(:cred) { described_class.new(auth.id, @base_dir) }

    describe "#command_line" do
      it "returns an empty hash" do
        expect(cred.command_line).to eq({})
      end
    end

    # Modeled off of rhv injectors for awx:
    #
    #   https://github.com/ansible/awx/blob/1242ee2b/awx/main/models/credential/__init__.py#L1035-L1054
    #
    describe "#env_vars" do
      it "sets OVIRT_INI_PATH, OVIRT_URL, OVIRT_USERNAME, and OVIRT_PASSWORD" do
        filename = File.join(@base_dir, "ovirt.ini")
        expected = {
          "OVIRT_INI_PATH" => filename,
          "OVIRT_URL"      => "rhv_host",
          "OVIRT_USERNAME" => "manageiq-rhv",
          "OVIRT_PASSWORD" => "rhv_password"
        }

        expect(cred.env_vars).to eq(expected)
      end

      it "defaults OVIRT_URL, OVIRT_USERNAME, and OVIRT_PASSWORD to ''" do
        auth.update!(:userid => nil, :password => nil, :options => nil)

        filename = File.join(@base_dir, "ovirt.ini")
        expected = {
          "OVIRT_INI_PATH" => filename,
          "OVIRT_URL"      => "",
          "OVIRT_USERNAME" => "",
          "OVIRT_PASSWORD" => ""
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
      it "writes the ini file" do
        cred.write_config_files

        actual_data   = File.read(File.join(@base_dir, "ovirt.ini"))
        expected_data = <<~OVIRT_INI.strip
          [ovirt]
          ovirt_url=rhv_host
          ovirt_username=manageiq-rhv
          ovirt_password=rhv_password
        OVIRT_INI

        expect(expected_data).to eq(actual_data)
      end

      it "fills in empty data (matching awx implementation)" do
        auth.update!(:userid => nil, :password => nil, :options => nil)
        cred.write_config_files

        actual_data   = File.read(File.join(@base_dir, "ovirt.ini"))
        expected_data = <<~OVIRT_INI.strip
          [ovirt]
          ovirt_url=
          ovirt_username=
          ovirt_password=
        OVIRT_INI

        expect(expected_data).to eq(actual_data)
      end

      it "handles empty options hash" do
        auth.update!(:options => {})
        cred.write_config_files

        actual_data   = File.read(File.join(@base_dir, "ovirt.ini"))
        expected_data = <<~OVIRT_INI.strip
          [ovirt]
          ovirt_url=
          ovirt_username=manageiq-rhv
          ovirt_password=rhv_password
        OVIRT_INI

        expect(expected_data).to eq(actual_data)
      end
    end
  end
end
