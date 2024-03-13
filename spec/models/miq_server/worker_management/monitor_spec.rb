RSpec.describe MiqServer::WorkerManagement::Monitor do
  context "#check_not_responding" do
    let(:server) { EvmSpecHelper.local_miq_server }
    let(:worker) do
      FactoryBot.create(:miq_worker,
                         :type           => "MiqGenericWorker",
                         :miq_server     => server,
                         :pid            => 12345,
                         :last_heartbeat => 5.minutes.ago)
    end

    before do
      server.worker_manager.worker_add(worker.pid)
    end

    it "destroys an unresponsive 'stopping' worker" do
      expect(Process).to receive(:kill).with("TERM", worker.pid)
      expect(Process).to receive(:kill).with(9, worker.pid)
      worker.update(:last_heartbeat => 20.minutes.ago)
      server.worker_manager.stop_worker(worker)
      server.worker_manager.check_not_responding
      server.reload
      expect(server.miq_workers).to be_empty
      expect { worker.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "monitors recently heartbeated 'stopping' workers" do
      expect(Process).to receive(:kill).with("TERM", worker.pid)
      worker.update(:last_heartbeat => 1.minute.ago)
      server.worker_manager.stop_worker(worker)
      server.worker_manager.check_not_responding
      server.reload
      expect(server.miq_workers.first.id).to eq(worker.id)
    end

    context "#sync_workers" do
      let(:server) { EvmSpecHelper.local_miq_server }

      it "rescues exceptions and moves on" do
        allow(MiqWorkerType).to receive(:worker_class_names).and_return(%w[MiqGenericWorker MiqPriorityWorker])
        allow(MiqGenericWorker).to receive(:sync_workers).and_raise
        expect(MiqPriorityWorker).to receive(:sync_workers).and_return(:adds => [123])

        server.worker_manager.sync_workers

        expect(server.worker_manager.workers.keys).to include(123)
      end
    end
  end
end
