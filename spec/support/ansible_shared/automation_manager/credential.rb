require 'ansible_tower_client'

shared_examples_for "ansible credential" do
  let(:finished_task) { FactoryGirl.create(:miq_task, :state => "Finished") }
  let(:atc)           { double("AnsibleTowerClient::Connection", :api => api) }
  let(:api)           { double("AnsibleTowerClient::Api", :credentials => credentials) }

  context "Create through API" do
    let(:credentials)     { double("AnsibleTowerClient::Collection", :create! => credential) }
    let(:credential)      { AnsibleTowerClient::Credential.new(nil, credential_json) }
    let(:credential_json) do
      params.merge(
        :id => 10,
      ).stringify_keys.to_json
    end
    let(:params) do
      {
        :description => "Description",
        :name        => "My Credential",
        :related     => {},
        :userid      => 'john'
      }
    end
    let(:expected_params) do
      {
        :description => "Description",
        :name        => "My Credential",
        :related     => {},
        :username    => "john",
        :kind        => described_class::TOWER_KIND
      }
    end
    let(:expected_notify_params) do
      {
        :description => "Description",
        :name        => "My Credential",
        :related     => {},
        :username    => "john",
        :kind        => described_class::TOWER_KIND
      }
    end
    let(:expected_notify) do
      {
        :type    => :tower_op_success,
        :options => {
          :op_name => "#{described_class.name.demodulize} create_in_provider",
          :op_arg  => expected_params.to_s,
          :tower   => "Tower(manager_id: #{manager.id})"
        }
      }
    end

    it ".create_in_provider to succeed and send notification" do
      expected_params[:organization] = 1 if described_class.name.include?("::EmbeddedAnsible::")
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      store_new_credential(credential, manager)
      expect(EmsRefresh).to receive(:queue_refresh_task).and_return([finished_task])
      expect(ExtManagementSystem).to receive(:find).with(manager.id).and_return(manager)
      expect(credentials).to receive(:create!).with(expected_params)
      expect(Notification).to receive(:create).with(expected_notify)
      expect(described_class.create_in_provider(manager.id, params)).to be_a(described_class)
    end

    it ".create_in_provider to fail (not found during refresh) and send notification" do
      expected_params[:organization] = 1 if described_class.name.include?("::EmbeddedAnsible::")
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(EmsRefresh).to receive(:queue_refresh_task).and_return([finished_task])
      expect(ExtManagementSystem).to receive(:find).with(manager.id).and_return(manager)
      expect(credentials).to receive(:create!).with(expected_params)
      expected_notify[:type] = :tower_op_failure
      expect(Notification).to receive(:create).with(expected_notify).and_return(double(Notification))
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
    let(:credential)    { double("AnsibleTowerClient::Credential", :destroy! => nil, :id => '1') }
    let(:ansible_cred)  { described_class.create!(:resource => manager, :manager_ref => credential.id) }
    let(:expected_notify) do
      {
        :type    => :tower_op_success,
        :options => {
          :op_name => "#{described_class.name.demodulize} delete_in_provider",
          :op_arg  => {:manager_ref => credential.id}.to_s,
          :tower   => "Tower(manager_id: #{manager.id})"
        }
      }
    end

    it "#delete_in_provider to succeed and send notification" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(EmsRefresh).to receive(:queue_refresh_task).and_return([finished_task])
      expect(Notification).to receive(:create).with(expected_notify)
      ansible_cred.delete_in_provider
    end

    it "#delete_in_provider to fail (finding credential) and send notification" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      allow(credentials).to receive(:find).and_raise(AnsibleTowerClient::ClientError)
      expected_notify[:type] = :tower_op_failure
      expect(Notification).to receive(:create).with(expected_notify)
      expect { ansible_cred.delete_in_provider }.to raise_error(AnsibleTowerClient::ClientError)
    end

    it "#delete_in_provider_queue" do
      task_id = ansible_cred.delete_in_provider_queue
      expect(MiqTask.find(task_id)).to have_attributes(:name => "Deleting #{described_class.name} with Tower internal reference=#{ansible_cred.manager_ref}")
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
    let(:credentials)     { double("AnsibleTowerClient::Collection", :find => credential) }
    let(:credential)      { double("AnsibleTowerClient::Credential", :id => 1) }
    let(:ansible_cred)    { described_class.create!(:resource => manager, :manager_ref => credential.id) }
    let(:params)          { {:userid => 'john'} }
    let(:expected_params) { {:username => 'john', :kind => described_class::TOWER_KIND} }
    let(:expected_notify) do
      {
        :type    => :tower_op_success,
        :options => {
          :op_name => "#{described_class.name.demodulize} update_in_provider",
          :op_arg  => expected_params.to_s,
          :tower   => "Tower(manager_id: #{manager.id})"
        }
      }
    end

    it "#update_in_provider to succeed and send notification" do
      expected_params[:organization] = 1 if described_class.name.include?("::EmbeddedAnsible::")
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(credential).to receive(:update_attributes!).with(expected_params)
      expect(EmsRefresh).to receive(:queue_refresh_task).and_return([finished_task])
      expect(Notification).to receive(:create).with(expected_notify)
      expect(ansible_cred.update_in_provider(params)).to be_a(described_class)
    end

    it "#update_in_provider to fail (doing update_attributes!) and send notification" do
      expected_params[:organization] = 1 if described_class.name.include?("::EmbeddedAnsible::")
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(credential).to receive(:update_attributes!).with(expected_params).and_raise(AnsibleTowerClient::ClientError)
      expected_notify[:type] = :tower_op_failure
      expect(Notification).to receive(:create).with(expected_notify).and_return(double(Notification))
      expect { ansible_cred.update_in_provider(params) }.to raise_error(AnsibleTowerClient::ClientError)
    end

    it "#update_in_provider_queue" do
      task_id = ansible_cred.update_in_provider_queue({})
      expect(MiqTask.find(task_id)).to have_attributes(:name => "Updating #{described_class.name} with Tower internal reference=#{ansible_cred.manager_ref}")
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
