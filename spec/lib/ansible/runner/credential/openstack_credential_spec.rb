require 'ansible/runner'
require 'ansible/runner/credential'

RSpec.describe Ansible::Runner::OpenstackCredential do
  it ".auth_type is the correct Authentication sub-class" do
    expect(described_class.auth_type).to eq("ManageIQ::Providers::EmbeddedAnsible::AutomationManager::OpenstackCredential")
  end

  context "with a credential object" do
    around do |example|
      Dir.mktmpdir("ansible-runner-credential-test") do |dir|
        @base_dir = dir
        example.run
      end
    end

    let(:auth) { FactoryBot.create(:embedded_ansible_openstack_credential, auth_attributes) }
    let(:auth_attributes) do
      {
        :userid   => "manageiq-openstack",
        :password => "openstack_password",
        :options  => {
          :host    => "http://fat.openstacks.example.com",
          :project => "project"
        }
      }
    end

    let(:cred) { described_class.new(auth.id, @base_dir) }

    describe "#command_line" do
      it "returns an empty hash" do
        expect(cred.command_line).to eq({})
      end
    end

    # Modeled off of openstack injectors for awx:
    #
    #   https://github.com/ansible/awx/blob/1242ee2b/awx/main/models/credential/injectors.py#L70-L96
    #
    describe "#env_vars" do
      it "sets OS_CLIENT_CONFIG_FILE" do
        filename = File.join(@base_dir, "os_credentials")
        expected = { "OS_CLIENT_CONFIG_FILE" => filename }
        expect(cred.env_vars).to eq(expected)
      end
    end

    describe "#extra_vars" do
      it "returns an empty hash" do
        expect(cred.extra_vars).to eq({})
      end
    end

    describe "#write_config_files" do
      it "writes the YAML data to a file" do
        cred.write_config_files

        actual_data   = YAML.load_file(File.join(@base_dir, "os_credentials"))
        expected_data = {
          "clouds" => {
            "devstack" => {
              "verify" => false,
              "auth"   => {
                "auth_url"     => "http://fat.openstacks.example.com",
                "username"     => "manageiq-openstack",
                "password"     => "openstack_password",
                "project_name" => "project"
              }
            }
          }
        }

        expect(expected_data).to eq(actual_data)
      end

      it "files in empty data with emtpy strings (matching awx implementation)" do
        auth.update!(:userid => nil, :password => nil, :options => nil)
        cred.write_config_files

        actual_data   = YAML.load_file(File.join(@base_dir, "os_credentials"))
        expected_data = {
          "clouds" => {
            "devstack" => {
              "verify" => false,
              "auth"   => {
                "auth_url"     => "",
                "username"     => "",
                "password"     => "",
                "project_name" => ""
              }
            }
          }
        }

        expect(expected_data).to eq(actual_data)
      end

      it "handles empty options hash" do
        auth.update!(:options => auth.options.merge(:domain => "domain"))
        cred.write_config_files

        actual_data   = YAML.load_file(File.join(@base_dir, "os_credentials"))
        expected_data = {
          "clouds" => {
            "devstack" => {
              "verify" => false,
              "auth"   => {
                "auth_url"     => "http://fat.openstacks.example.com",
                "username"     => "manageiq-openstack",
                "password"     => "openstack_password",
                "project_name" => "project",
                "domain_name"  => "domain"
              }
            }
          }
        }

        expect(expected_data).to eq(actual_data)
      end
    end
  end
end
