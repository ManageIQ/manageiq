require "spec_helper"
require Rails.root.join("db/migrate/20110223170600_convert_miq_smis_agents_to_storage_managers.rb")

describe ConvertMiqSmisAgentsToStorageManagers do
  migration_context :up do
    let(:authentication_stub)  { migration_stub(:Authentication) }
    let(:storage_manager_stub) { migration_stub(:StorageManager) }
    let(:miq_smis_agent_stub)  { Class.new(ActiveRecord::Base).tap { |m| m.table_name = "miq_smis_agents" } }

    it "updates StorageManager type to MiqSmisAgent" do
      agent    = miq_smis_agent_stub.create!
      agent_id = agent.id
      auth     = authentication_stub.create!(:resource_type => "MiqSmisAgent", :resource_id => agent_id)

      migrate

      storage_manager_stub.find(agent_id).type.should == "MiqSmisAgent"
      auth.reload.resource_type.should == "StorageManager"
    end

    it "ignores other authentications" do
      auth = authentication_stub.create!(:resource_type => "SomeClass", :resource_id => 1)
      orig_attributes = auth.attributes

      migrate

      auth.reload.should have_attributes(orig_attributes)
    end
  end

  migration_context :down do
    let(:authentication_stub)  { migration_stub(:Authentication) }
    let(:storage_manager_stub) { migration_stub(:StorageManager) }
    let(:miq_smis_agent_stub)  { Class.new(ActiveRecord::Base).tap { |m| m.table_name = "miq_smis_agents" } }

    it "updates MiqSmisAgent type to StorageManager" do
      sm    = storage_manager_stub.create!(:type => "MiqSmisAgent")
      sm_id = sm.id
      auth  = authentication_stub.create!(:resource_type => "StorageManager", :resource_id => sm_id)

      migrate

      miq_smis_agent_stub.where(:id => sm_id).should exist
      auth.reload.resource_type.should == "MiqSmisAgent"
    end

    it "removes non-MiqSmisAgent StorageManagers" do
      sm    = storage_manager_stub.create!(:type => "OtherSmisAgent")
      sm_id = sm.id
      auth  = authentication_stub.create!(:resource_type => "StorageManager", :resource_id => sm_id)

      migrate

      miq_smis_agent_stub.where(:id => sm_id).should_not exist
      lambda { auth.reload }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
