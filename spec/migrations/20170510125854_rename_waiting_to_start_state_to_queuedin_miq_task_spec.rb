require_migration

describe RenameWaitingToStartStateToQueuedinMiqTask do
  let(:task_stub) { migration_stub(:MiqTask) }
  let(:task_name) { "Hello Test Task" }
  let(:state_queued) { "Queued" }
  let(:state_waiting_to_start) { "Waiting_to_start" }

  migration_context :up do
    it "updates 'state' attribute on 'miq_tasks' table from 'Waiting_to_start' to 'Queued'" do
      task_stub.create!(:name => task_name, :state => state_waiting_to_start)

      migrate

      expect(task_stub.find_by(:name => task_name).state).to eq state_queued
    end
  end

  migration_context :down do
    let(:job_stub) { migration_stub(:Job) }

    it "updates 'state' attribute on 'miq_tasks' table from 'Waiting_to_start' to 'Queued'" do
      task = task_stub.create!(:name => task_name, :state => state_queued)
      job_stub.create!(:miq_task_id => task.id)
      task_stub.create!(:name => "Second task not linked to job", :state => state_queued)
      expect(task_stub.where(:state => state_queued).count).to eq 2

      migrate

      expect(task_stub.where(:state => state_queued).count).to eq 1
      expect(task_stub.where(:state => state_waiting_to_start).count).to eq 1
    end
  end
end
