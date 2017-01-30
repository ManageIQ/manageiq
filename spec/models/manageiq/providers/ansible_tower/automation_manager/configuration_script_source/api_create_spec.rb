require 'ansible_tower_client'

describe ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScriptSource do
  context "::ApiCreate" do
    let(:provider)      { FactoryGirl.create(:provider_ansible_tower, :with_authentication) }
    let(:manager)       { provider.managers.first }
    let(:atc)           { double("AnsibleTowerClient::Connection", :api => api) }
    let(:api)           { double("AnsibleTowerClient::Api", :projects => projects) }
    let(:projects)      { double("AnsibleTowerClient::Collection", :create! => project) }
    let(:project)       { AnsibleTowerClient::Project.new(nil, project_json) }

    let(:project_json) do
      params.merge(
        :id        => 10,
        "scm_type" => "git",
        "scm_url"  => "https://github.com/ansible/ansible-tower-samples"
      ).stringify_keys.to_json
    end

    let(:params) do
      {
        :description  => "Description",
        :name         => "My Project",
        :related      => {}
      }
    end

    it ".create_in_provider" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(EmsRefresh).to receive(:queue_refresh).and_return(store_new_project(project, manager))
      expect(ExtManagementSystem).to receive(:find).with(manager.id).and_return(manager)

      expect(described_class.create_in_provider(manager.id, params)).to be_a(described_class)
    end

    it ".create_in_provider_queue" do
      EvmSpecHelper.local_miq_server
      task_id = described_class.create_in_provider_queue(manager.id, params)
      expect(MiqTask.find(task_id)).to have_attributes(:name => "Creating Ansible Tower Project")
      expect(MiqQueue.first).to have_attributes(
        :args        => [manager.id, params],
        :class_name  => "ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScriptSource",
        :method_name => "create_in_provider",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "ems_operations",
        :zone        => manager.zone_id
      )
    end

    def store_new_project(project, manager)
      described_class.create!(
        :manager     => manager,
        :manager_ref => project.id.to_s,
        :name        => project.name,
      )
    end
  end
end
