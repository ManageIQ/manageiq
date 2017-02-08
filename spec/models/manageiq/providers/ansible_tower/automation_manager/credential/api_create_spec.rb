require 'ansible_tower_client'

describe ManageIQ::Providers::AnsibleTower::AutomationManager::Credential do
  context "::ApiCreate" do
    let(:provider)      { FactoryGirl.create(:provider_ansible_tower, :with_authentication) }
    let(:manager)       { provider.managers.first }
    let(:atc)           { double("AnsibleTowerClient::Connection", :api => api) }
    let(:api)           { double("AnsibleTowerClient::Api", :credentials => credentials) }
    let(:credentials)   { double("AnsibleTowerClient::Collection", :create! => credential) }
    let(:credential)    { AnsibleTowerClient::Credential.new(nil, credential_json) }

    let(:credential_json) do
      params.merge(
        :id => 10,
      ).stringify_keys.to_json
    end

    let(:params) do
      {
        :description  => "Description",
        :name         => "My Credential",
        :related      => {}
      }
    end

    it ".create_in_provider" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(EmsRefresh).to receive(:queue_refresh).and_return(store_new_credential(credential, manager))
      expect(ExtManagementSystem).to receive(:find).with(manager.id).and_return(manager)

      expect(described_class.create_in_provider(manager.id, params)).to be_a(described_class)
    end

    it ".create_in_provider_queue" do
      EvmSpecHelper.local_miq_server
      task_id = described_class.create_in_provider_queue(manager.id, params)
      expect(MiqTask.find(task_id)).to have_attributes(:name => "Creating ManageIQ::Providers::AnsibleTower::AutomationManager::Credential")
      expect(MiqQueue.first).to have_attributes(
        :args        => [manager.id, params],
        :class_name  => "ManageIQ::Providers::AnsibleTower::AutomationManager::Credential",
        :method_name => "create_in_provider",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "ems_operations",
        :zone        => manager.my_zone
      )
    end

    def store_new_credential(credential, manager)
      described_class.create!(
        :resource    => manager,
        :manager_ref => credential.id.to_s,
        :name        => credential.name,
      )
    end
  end
end
