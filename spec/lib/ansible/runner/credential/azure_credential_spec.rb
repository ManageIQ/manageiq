require 'ansible/runner'
require 'ansible/runner/credential'

RSpec.describe Ansible::Runner::AzureCredential do
  it ".auth_type is the correct Authentication sub-class" do
    expect(described_class.auth_type).to eq("ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AzureCredential")
  end

  context "with a credential object" do
    around do |example|
      Dir.mktmpdir("ansible-runner-credential-test") do |dir|
        @base_dir = dir
        example.run
      end
    end

    let(:auth) { FactoryBot.create(:embedded_ansible_azure_credential, auth_attributes) }
    let(:auth_attributes) do
      {
        :userid   => "manageiq-azure",
        :password => "azure_password",
        :auth_key => "client_secret",
        :options  => {
          :client       => "client_id",
          :tenant       => "tenant_id",
          :subscription => "subscription_id"
        }
      }
    end

    let(:cred) { described_class.new(auth.id, @base_dir) }

    describe "#command_line" do
      it "returns an empty hash" do
        expect(cred.command_line).to eq({})
      end
    end

    # Modeled off of azure injectors for awx:
    #
    #   https://github.com/ansible/awx/blob/1242ee2b/awx/main/models/credential/injectors.py#L45-L60
    #
    describe "#env_vars" do
      context "client_id and tenant_id present" do
        let(:auth_attributes) do
          {
            :auth_key => "client_secret",
            :options  => {
              :client => "client_id",
              :tenant => "tenant_id"
            }
          }
        end

        it "sets AZURE_CLIENT_ID, AZURE_TENANT, and AZURE_SECRET" do
          expected = {
            "AZURE_CLIENT_ID"       => "client_id",
            "AZURE_TENANT"          => "tenant_id",
            "AZURE_SECRET"          => "client_secret",
            "AZURE_SUBSCRIPTION_ID" => ""
          }
          expect(cred.env_vars).to eq(expected)
        end

        it "defaults AZURE_SECRET to '' if missing" do
          auth.update!(:auth_key => nil)
          expected = {
            "AZURE_CLIENT_ID"       => "client_id",
            "AZURE_TENANT"          => "tenant_id",
            "AZURE_SECRET"          => "",
            "AZURE_SUBSCRIPTION_ID" => ""
          }
          expect(cred.env_vars).to eq(expected)
        end

        it "adds AZURE_SUBSCRIPTION_ID if present" do
          auth.update!(:options => auth.options.merge(:subscription => "subscription_id"))
          expected = {
            "AZURE_CLIENT_ID"       => "client_id",
            "AZURE_TENANT"          => "tenant_id",
            "AZURE_SECRET"          => "client_secret",
            "AZURE_SUBSCRIPTION_ID" => "subscription_id"
          }
          expect(cred.env_vars).to eq(expected)
        end
      end

      context "client_id and tenant_id missing" do
        let(:auth_attributes) do
          {
            :userid   => "manageiq-azure",
            :password => "azure_password"
          }
        end

        it "sets AZURE_AD_USER and AZURE_PASSWORD" do
          expected = {
            "AZURE_AD_USER"         => "manageiq-azure",
            "AZURE_PASSWORD"        => "azure_password",
            "AZURE_SUBSCRIPTION_ID" => ""
          }
          expect(cred.env_vars).to eq(expected)
        end

        it "defaults AZURE_AD_USER and AZURE_PASSWORD to ''" do
          auth.update!(:userid => nil, :password => nil)
          expected = {
            "AZURE_AD_USER"         => "",
            "AZURE_PASSWORD"        => "",
            "AZURE_SUBSCRIPTION_ID" => ""
          }
          expect(cred.env_vars).to eq(expected)
        end

        it "adds AWS_SECURITY_TOKEN if present" do
          auth.update!(:options => { :subscription => "subscription_id" })
          expected = {
            "AZURE_AD_USER"         => "manageiq-azure",
            "AZURE_PASSWORD"        => "azure_password",
            "AZURE_SUBSCRIPTION_ID" => "subscription_id"
          }
          expect(cred.env_vars).to eq(expected)
        end
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
