require 'ansible_tower_client'

describe ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScriptSource do
  let(:finished_task) { FactoryGirl.create(:miq_task, :state => "Finished") }
  let(:manager)       { FactoryGirl.create(:provider_ansible_tower, :with_authentication).managers.first }
  let(:atc)           { double("AnsibleTowerClient::Connection", :api => api) }
  let(:api)           { double("AnsibleTowerClient::Api", :projects => projects) }

  context "create through API" do
    let(:projects) { double("AnsibleTowerClient::Collection", :create! => project) }
    let(:project)  { AnsibleTowerClient::Project.new(nil, project_json) }

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
      store_new_project(project, manager)
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
      EvmSpecHelper.local_miq_server
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

    def store_new_project(project, manager)
      described_class.create!(
        :manager     => manager,
        :manager_ref => project.id.to_s,
        :name        => project.name,
      )
    end
  end

  context "Delete through API" do
    let(:projects)      { double("AnsibleTowerClient::Collection", :find => tower_project) }
    let(:tower_project) { double("AnsibleTowerClient::Project", :destroy! => nil, :id => 1) }
    let(:project)       { described_class.create!(:manager => manager, :manager_ref => tower_project.id) }

    it "#delete_in_provider" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(EmsRefresh).to receive(:queue_refresh_task).and_return([finished_task])
      project.delete_in_provider
    end

    it "#delete_in_provider_queue" do
      task_id = project.delete_in_provider_queue
      expect(MiqTask.find(task_id)).to have_attributes(:name => "Deleting #{described_class.name} with manager_ref=#{project.manager_ref}")
      expect(MiqQueue.first).to have_attributes(
        :instance_id => project.id,
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
    let(:projects)      { double("AnsibleTowerClient::Collection", :find => tower_project) }
    let(:tower_project) { double("AnsibleTowerClient::Project", :update_attributes! => {}, :id => 1) }
    let(:project)       { described_class.create!(:manager => manager, :manager_ref => tower_project.id) }

    it "#update_in_provider" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(EmsRefresh).to receive(:queue_refresh_task).and_return([finished_task])
      expect(project.update_in_provider({})).to be_a(described_class)
    end

    it "#update_in_provider_queue" do
      task_id = project.update_in_provider_queue({})
      expect(MiqTask.find(task_id)).to have_attributes(:name => "Updating #{described_class.name} with manager_ref=#{project.manager_ref}")
      expect(MiqQueue.first).to have_attributes(
        :instance_id => project.id,
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
