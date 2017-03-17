require_migration

describe CopyAgentIdToMiqServerIdInJobsTable do
  let(:jobs_stub) { migration_stub(:Job) }

  migration_context :up do
    it "copies data from 'agent_id' to 'miq_server_id' column on jobs table" do
      jobs_stub.create!(:name => "Hello Test Job", :agent_id => 111)
      migrate
      expect(Job.find_by(:name => "Hello Test Job").miq_server_id).to eq 111
    end
  end

  migration_context :down do
    it "nullifies 'miq_server_id' column on jobs table" do
      jobs_stub.create!(:name => "Hello Test Job", :miq_server_id => 111)
      migrate
      expect(Job.find_by(:name => "Hello Test Job").miq_server_id).to be nil
    end
  end
end
