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
  end
end
