require 'ansible_tower_client'
require 'faraday'
describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript do
  let(:api)          { double(:api, :job_templates => double(:job_templates)) }
  let(:connection)   { double(:connection, :api => api) }
  let(:job)          { AnsibleTowerClient::Job.new(connection.api, "id" => 1) }
  let(:job_template) { AnsibleTowerClient::JobTemplate.new(connection.api, "limit" => "", "id" => 1, "url" => "api/job_templates/1/", "name" => "template", "description" => "description", "extra_vars" => {:instance_ids => ['i-3434']}) }
  let(:manager)      { FactoryGirl.create(:embedded_automation_manager_ansible, :provider, :configuration_script) }

  it "belongs_to the Ansible Tower manager" do
    expect(manager.configuration_scripts.size).to eq 1
    expect(manager.configuration_scripts.first.variables).to eq :instance_ids => ['i-3434']
    expect(manager.configuration_scripts.first).to be_a ConfigurationScript
  end

  context "relates to playbook" do
    let(:configuration_script_source) { FactoryGirl.create(:configuration_script_source, :manager => manager) }
    let!(:payload) { FactoryGirl.create(:configuration_script_payload) }
    let(:configuration_scripts_without_payload) { FactoryGirl.create(:configuration_script) }
    let(:configuration_scripts) do
      [FactoryGirl.create(:configuration_script, :parent => payload),
       FactoryGirl.create(:configuration_script, :parent => payload)]
    end

    it "can refer to a payload" do
      expect(configuration_scripts[0].parent).to eq(payload)
      expect(configuration_scripts[1].parent).to eq(payload)
      expect(payload.children).to match_array(configuration_scripts)
    end

    it "can be without payload" do
      expect(configuration_scripts_without_payload.parent).to be_nil
    end
  end

  context "#run" do
    before do
      allow_any_instance_of(Provider).to receive_messages(:connect => connection)
      allow(api.job_templates).to receive(:find) { job_template }
    end

    it "launches the referenced ansible job template" do
      expect(job_template).to receive(:launch).with(:extra_vars => "{\"instance_ids\":[\"i-3434\"]}").and_return(job)
      expect(manager.configuration_scripts.first.run).to be_a AnsibleTowerClient::Job
    end

    it "accepts different variables to launch a job template against" do
      added_extras = {:extra_vars => {:some_key => :some_value}}
      expect(job_template).to receive(:launch).with(:extra_vars=>"{\"instance_ids\":[\"i-3434\"],\"some_key\":\"some_value\"}").and_return(job)
      expect(manager.configuration_scripts.first.run(added_extras)).to be_a AnsibleTowerClient::Job
    end
  end

  context "#merge_extra_vars" do
    it "merges internal and external hashes to send out to the tower gem" do
      config_script = manager.configuration_scripts.first
      external = {:some_key => :some_value}
      internal = config_script.variables
      expect(internal).to be_a Hash
      expect(config_script.merge_extra_vars(external)).to eq(:extra_vars => "{\"instance_ids\":[\"i-3434\"],\"some_key\":\"some_value\"}")
    end

    it "merges an internal hash and an empty hash to send out to the tower gem" do
      config_script = manager.configuration_scripts.first
      external = nil
      expect(config_script.merge_extra_vars(external)).to eq(:extra_vars => "{\"instance_ids\":[\"i-3434\"]}")
    end

    it "merges an empty internal hash and a hash to send out to the tower gem" do
      external = {:some_key => :some_value}
      internal = {}
      config_script = manager.configuration_scripts.first
      config_script.variables = internal
      expect(config_script.merge_extra_vars(external)).to eq(:extra_vars => "{\"some_key\":\"some_value\"}")
    end

    it "merges all empty arguments to send out to the tower gem" do
      external = nil
      internal = {}
      config_script = manager.configuration_scripts.first
      config_script.variables = internal
      expect(config_script.merge_extra_vars(external)).to eq(:extra_vars => "{}")
    end
  end

  context "creates via the API" do
    let(:provider)      { FactoryGirl.create(:provider_embedded_ansible, :with_authentication) }
    let(:manager)       { provider.managers.first }
    let(:atc)           { double("AnsibleTowerClient::Connection", :api => api) }
    let(:api)           { double("AnsibleTowerClient::Api", :job_templates => job_templates) }
    let(:job_templates) { double("AnsibleTowerClient::Collection", :create! => job_template) }
    let(:job_template)  { AnsibleTowerClient::JobTemplate.new(nil, job_template_json) }

    let(:job_template_json) do
      params.merge(
        :id        => 10,
        :inventory => 1,
        :related   => {"inventory" => "blah/1"}
      ).except(:inventory_id).stringify_keys.to_json
    end

    let(:params) do
      {
        :description  => "Description",
        :extra_vars   => {}.to_json,
        :inventory_id => 1,
        :name         => "My Job Template",
        :related      => {}
      }
    end

    context ".create_in_provider" do
      let(:finished_task) { FactoryGirl.create(:miq_task, :state => "Finished") }

      it "successfully created in provider" do
        expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)

        store_new_job_template(job_template, manager)

        expect(EmsRefresh).to receive(:queue_refresh_task).and_return([finished_task])
        expect(ExtManagementSystem).to receive(:find).with(manager.id).and_return(manager)

        expect(described_class.create_in_provider(manager.id, params)).to be_a(described_class)
      end

      it "not found during refresh" do
        expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
        expect(EmsRefresh).to receive(:queue_refresh_task).and_return([finished_task])
        expect(ExtManagementSystem).to receive(:find).with(manager.id).and_return(manager)

        expect { described_class.create_in_provider(manager.id, params) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    it ".create_in_provider_queue" do
      EvmSpecHelper.local_miq_server
      task_id = described_class.create_in_provider_queue(manager.id, params)
      expect(MiqTask.find(task_id)).to have_attributes(:name => "Creating Ansible Tower Job Template")
      expect(MiqQueue.first).to have_attributes(
        :args        => [manager.id, params],
        :class_name  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript",
        :method_name => "create_in_provider",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "ems_operations",
        :zone        => manager.zone.name
      )
    end

    def store_new_job_template(job_template, manager)
      described_class.create!(
        :manager     => manager,
        :manager_ref => job_template.id.to_s,
        :name        => job_template.name,
        :survey_spec => job_template.survey_spec_hash,
        :variables   => job_template.extra_vars_hash,
      )
    end
  end

  it '#jobs' do
    job_template = FactoryGirl.create(:embedded_configuration_script)
    job = FactoryGirl.create(:embedded_ansible_job, :job_template => job_template)

    expect(job_template.jobs).to eq([job])
  end
end
