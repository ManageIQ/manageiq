require 'ansible_tower_client'

describe ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript do
  context "::ApiCreate" do
    let(:provider)      { FactoryGirl.create(:provider_ansible_tower, :with_authentication) }
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

    it ".create_in_provider" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(EmsRefresh).to receive(:queue_refresh).and_return(store_new_job_template(job_template, manager))
      expect(ExtManagementSystem).to receive(:find).with(manager.id).and_return(manager)

      expect(described_class.create_in_provider(manager.id, params)).to be_a(described_class)
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
end
