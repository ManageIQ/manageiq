require_migration

describe CreateTaskForEachJobAndTransferAttributes do
  let(:miq_tasks_stub) { migration_stub(:MiqTask) }
  let(:jobs_stub) { migration_stub(:Job) }

  migration_context :up do
    it "creates associated task for each job and assigns to task the same name" do
      jobs_stub.create!(:name => "Hello Test Job", :status => "Some test status", :miq_task_id => nil)
      jobs_stub.create!(:name => "Hello Test Job2", :state => "Some state", :miq_task_id => nil)

      migrate

      expect(miq_tasks_stub.count).to eq 2
      expect(MiqTask.find_by(:name => "Hello Test Job").status).to eq "Some test status"
      expect(MiqTask.find_by(:name => "Hello Test Job2").state).to eq "Some state"
    end
  end

  migration_context :down do
    it "delete all tasks associated with jobs" do
      job = jobs_stub.create!(:name => "Hello Test Job")
      task_with_job = miq_tasks_stub.create!(:name => "Hello Test Job")
      job.update_attributes(:miq_task_id => task_with_job.id)
      miq_tasks_stub.create!(:name => "Task without Job")
      miq_tasks_stub.create!(:name => "Another Task without Job")

      expect(miq_tasks_stub.count).to eq 3

      migrate

      expect(jobs_stub.count).to eq 1
      expect(miq_tasks_stub.count).to eq 2
      expect(jobs_stub.first.miq_task_id).to be nil
    end
  end
end
