require_migration

describe CopyServerIdFromJobsToMiqTasks do
  let(:task_name) { "Hello Test Task" }
  let(:task_stub) { migration_stub(:MiqTask) }
  let(:job_stub) { migration_stub(:Job) }
  let(:server_id) { anonymous_class_with_id_regions.rails_sequence_start }

  migration_context :up do
    it "copies data from 'jobs.miq_server_id' to 'miq_tasks.miq_server_id'" do
      task = task_stub.create!(:name => task_name)
      job_stub.create!(:miq_server_id => server_id, :miq_task_id => task.id)

      migrate

      expect(task.reload.miq_server_id).to eq server_id
    end
  end

  migration_context :down do
    it "nullifying miq_server_id column on miq_tasks table" do
      task = task_stub.create!(:name => task_name, :miq_server_id => server_id)

      migrate

      expect(task.reload.miq_server_id).to be nil
    end
  end
end
