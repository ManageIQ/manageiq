require 'ansible_tower_client'

describe ManageIQ::Providers::AnsibleTower::AutomationManager::Credential do
  let(:finished_task) { FactoryGirl.create(:miq_task, :state => "Finished") }
  let(:manager)       { FactoryGirl.create(:provider_ansible_tower, :with_authentication).managers.first }
  let(:atc)           { double("AnsibleTowerClient::Connection", :api => api) }
  let(:api)           { double("AnsibleTowerClient::Api", :credentials => credentials) }

  context "Create through API" do
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
      store_new_credential(credential, manager)
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

    it ".create_in_provider_queue" do
      task_id = described_class.create_in_provider_queue(manager.id, params)
      expect(MiqTask.find(task_id)).to have_attributes(:name => "Creating #{described_class.name} with name=#{params[:name]}")
      expect(MiqQueue.first).to have_attributes(
        :args        => [manager.id, params],
        :class_name  => described_class.name,
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

  context "Delete through API" do
    let(:credentials)   { double("AnsibleTowerClient::Collection", :find => credential) }
    let(:credential)    { double("AnsibleTowerClient::Credential", :destroy! => nil, :id => 1) }
    let(:ansible_cred)  { described_class.create!(:resource => manager, :manager_ref => credential.id) }

    it "#delete_in_provider" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(EmsRefresh).to receive(:queue_refresh_task).and_return([finished_task])
      ansible_cred.delete_in_provider
    end

    it "#delete_in_provider_queue" do
      task_id = ansible_cred.delete_in_provider_queue
      expect(MiqTask.find(task_id)).to have_attributes(:name => "Deleting #{described_class.name} with manager_ref=#{ansible_cred.manager_ref}")
      expect(MiqQueue.first).to have_attributes(
        :instance_id => ansible_cred.id,
        :args        => [],
        :class_name  => described_class.name,
        :method_name => "delete_in_provider",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "ems_operations",
        :zone        => manager.my_zone
      )
    end
  end

  context "Update through API" do
    let(:credentials)   { double("AnsibleTowerClient::Collection", :find => credential) }
    let(:credential)    { double("AnsibleTowerClient::Credential", :update_attributes! => {}, :id => 1) }
    let(:ansible_cred)  { described_class.create!(:resource => manager, :manager_ref => credential.id) }

    it "#update_in_provider" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(EmsRefresh).to receive(:queue_refresh_task).and_return([finished_task])
      expect(ansible_cred.update_in_provider({})).to be_a(described_class)
    end

    it "#update_in_provider_queue" do
      task_id = ansible_cred.update_in_provider_queue({})
      expect(MiqTask.find(task_id)).to have_attributes(:name => "Updating #{described_class.name} with manager_ref=#{ansible_cred.manager_ref}")
      expect(MiqQueue.first).to have_attributes(
        :instance_id => ansible_cred.id,
        :args        => [{:task_id => task_id}],
        :class_name  => described_class.name,
        :method_name => "update_in_provider",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "ems_operations",
        :zone        => manager.my_zone
      )
    end
  end
end
