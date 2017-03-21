require_migration

describe CopyAgentIdToMiqServerIdInJobsTable do
  let(:job_stub) { migration_stub(:Job) }
  let(:job_name) { "Hello Test Job" }

  migration_context :up do
    it "copies data from 'agent_id' to 'miq_server_id' column on jobs table" do
      job_stub.create!(:name => job_name, :agent_id => 111)
      migrate
      expect(Job.find_by(:name => job_name).miq_server_id).to eq 111
    end
  end

  migration_context :down do
    it "nullifies 'miq_server_id' column on jobs table" do
      job_stub.create!(:name => job_name, :miq_server_id => 111)
      migrate
      expect(Job.find_by(:name => job_name).miq_server_id).to be nil
    end
  end
end
