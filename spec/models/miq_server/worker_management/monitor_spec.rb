describe MiqServer::WorkerManagement::Monitor do
  context "#check_not_responding" do
    let(:server) { EvmSpecHelper.local_miq_server }
    let(:worker) do
      FactoryGirl.create(:miq_worker,
                         :type           => "MiqGenericWorker",
                         :miq_server     => server,
                         :pid            => 12345,
                         :last_heartbeat => 5.minutes.ago)
    end

    before do
      server.setup_drb_variables
      server.worker_add(worker.pid)
    end

    it "destroys an unresponsive 'stopping' worker" do
      worker.update(:last_heartbeat => 20.minutes.ago)
      server.stop_worker(worker)
      server.check_not_responding
      server.reload
      expect(server.miq_workers).to be_empty
      expect { worker.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "monitors recently heartbeated 'stopping' workers" do
      worker.update(:last_heartbeat => 1.minute.ago)
      server.stop_worker(worker)
      server.check_not_responding
      server.reload
      expect(server.miq_workers.first.id).to eq(worker.id)
    end

    context "#sync_workers" do
      let(:server) { EvmSpecHelper.local_miq_server }
      it "rescues exceptions and moves on" do
        allow(MiqServer).to receive(:monitor_class_names).and_return(%w(MiqGenericWorker MiqPriorityWorker))
        allow(MiqGenericWorker).to receive(:sync_workers).and_raise
        expect(MiqPriorityWorker).to receive(:sync_workers).and_return(:adds => [123])
        expect(server.sync_workers).to eq("MiqPriorityWorker"=>{:adds=>[123]})
      end
    end
  end
end
