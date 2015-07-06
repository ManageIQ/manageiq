require "spec_helper"
require Rails.root.join("db/migrate/20141219222843_remove_miq_worker_rows_without_model.rb")

describe RemoveMiqWorkerRowsWithoutModel do
  migration_context :up do
    let(:worker_stub) { migration_stub(:MiqWorker) }

    it "Removes rows where the model was deleted" do
      worker_stub.create!(:type => "MiqWorkerMonitor")
      worker_stub.create!(:type => "MiqStorageStatsCollectorWorker")
      worker_stub.create!(:type => "MiqPerfCollectorWorker")
      worker_stub.create!(:type => "MiqPerfProcessorWorker")
      not_orphaned = worker_stub.create!

      expect(worker_stub.count).to eql 5

      migrate

      expect(worker_stub.first).to eql not_orphaned
      expect(worker_stub.count).to eql 1
    end
  end
end
