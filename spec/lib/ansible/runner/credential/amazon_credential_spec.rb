require 'ansible/runner'
require 'ansible/runner/credential'

RSpec.describe Ansible::Runner::AmazonCredential do
  it ".auth_type is the correct Authentication sub-class" do
    expect(described_class.auth_type).to eq("ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AmazonCredential")
  end

  context "with a credential object" do
    around do |example|
      Dir.mktmpdir("ansible-runner-credential-test") do |dir|
        @base_dir = dir
        example.run
      end
    end

    let(:auth) { FactoryBot.create(:embedded_ansible_amazon_credential, auth_attributes) }
    let(:auth_attributes) do
      {
        :userid   => "manageiq-aws",
        :password => "aws_secret",
        :auth_key => "key_data"
      }
    end

    let(:cred) { described_class.new(auth.id, @base_dir) }

    describe "#command_line" do
      it "returns an empty hash" do
        expect(cred.command_line).to eq({})
      end
    end

    # Modeled off of aws injectors for awx:
    #
    #   https://github.com/ansible/awx/blob/1242ee2b/awx/main/models/credential/injectors.py#L11-L15
    #
    describe "#env_vars" do
      it "sets AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY" do
        auth.update!(:auth_key => nil)
        expected = {
          "AWS_ACCESS_KEY_ID"     => "manageiq-aws",
          "AWS_SECRET_ACCESS_KEY" => "aws_secret"
        }
        expect(cred.env_vars).to eq(expected)
      end

      it "defaults AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to ''" do
        auth.update!(:userid => nil, :password => nil, :auth_key => nil)
        expected = {
          "AWS_ACCESS_KEY_ID"     => "",
          "AWS_SECRET_ACCESS_KEY" => ""
        }
        expect(cred.env_vars).to eq(expected)
      end

      it "adds AWS_SECURITY_TOKEN if present" do
        expected = {
          "AWS_ACCESS_KEY_ID"     => "manageiq-aws",
          "AWS_SECRET_ACCESS_KEY" => "aws_secret",
          "AWS_SECURITY_TOKEN"    => "key_data"
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
