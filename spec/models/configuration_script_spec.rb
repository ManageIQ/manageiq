require 'ansible_tower_client'
require 'faraday'
describe ConfigurationScript do
  let(:faraday_connection) { instance_double("Faraday::Connection", :post => post, :get => get, :patch => '') }
  let(:post) { instance_double("Faraday::Result", :body => {}.to_json) }
  let(:get) { instance_double("Faraday::Result", :body => {'id' => 1}.to_json) }

  let(:connection) do
    double(:connection,
           :api => double(:api,
                          :job_templates => double(:job_templates, :find => job_template)
                         )
          )
  end
  let(:manager)      { FactoryGirl.create(:configuration_manager_ansible_tower, :provider, :configuration_script) }
  let(:mock_api)     { AnsibleTowerClient::Api.new(faraday_connection) }
  let(:job_template) { AnsibleTowerClient::JobTemplate.new(mock_api, "limit" => "", "id" => 1, "url" => "url", "name" => "template", "description" => "description", "extra_vars" => "{\n \"instance_ids\": [\"i-3434\"]}") }

  it "belongs_to the Ansible Tower manager" do
    expect(manager.configuration_scripts.size).to eq 1
    expect(manager.configuration_scripts.first.variables).to eq "{\n \"instance_ids\": [\"i-3434\"]}"
    expect(manager.configuration_scripts.first).to be_a ConfigurationScript
  end

  context "#run" do
    before do
      allow_any_instance_of(Provider).to receive_messages(:connect => connection)
      allow_any_instance_of(ManageIQ::Providers::ConfigurationManager).to receive_messages(:provider => manager.provider)
    end

    it "launches the referenced ansible job template" do
      expect(manager.provider).to be_a Provider
      expect(manager.configuration_scripts.first.run).to be_a AnsibleTowerClient::Job
    end

    it "accepts different variables to launch a job template against" do
      added_extras = {:extra_vars => {:some_key => :some_value}}
      expect(manager.configuration_scripts.first.run(added_extras)).to be_a AnsibleTowerClient::Job
      expect_any_instance_of(AnsibleTowerClient::JobTemplate).to receive(:launch).with(:extra_vars=>"{\"instance_ids\":[\"i-3434\"],\"some_key\":\"some_value\"}")
      manager.configuration_scripts.first.run(added_extras)
    end

    it "merges a json string and a hash to send out to the tower gem" do
      config_script = manager.configuration_scripts.first
      external = {:some_key => :some_value}
      internal = config_script.variables
      expect(internal).to be_a String
      expect(config_script.merge_extra_vars(external)).to eq(:extra_vars => "{\"instance_ids\":[\"i-3434\"],\"some_key\":\"some_value\"}")
    end

    it "merges a json string and an empty hash to send out to the tower gem" do
      config_script = manager.configuration_scripts.first
      external = nil
      expect(config_script.merge_extra_vars(external)).to eq(:extra_vars => "{\"instance_ids\":[\"i-3434\"]}")
    end

    it "merges an empty string and a hash to send out to the tower gem" do
      external = {:some_key => :some_value}
      internal = ""
      config_script = manager.configuration_scripts.first
      config_script.variables = internal
      expect(config_script.merge_extra_vars(external)).to eq(:extra_vars => "{\"some_key\":\"some_value\"}")
    end

    it "merges all empty arguments to send out to the tower gem" do
      external = nil
      internal = ""
      config_script = manager.configuration_scripts.first
      config_script.variables = internal
      expect(config_script.merge_extra_vars(external)).to eq(:extra_vars => "{}")
    end
  end
end
