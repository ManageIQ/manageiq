describe MiqServer::WorkerManagement::Heartbeat do
  context "#validate_heartbeat" do
    let(:miq_server) { EvmSpecHelper.local_miq_server.tap(&:setup_drb_variables) }
    let(:pid)        { 1234 }
    let(:worker)     { FactoryGirl.create(:miq_worker, :miq_server_id => miq_server.id, :pid => pid) }

    it "sets initial and subsequent heartbeats" do
      2.times do
        t = Time.now.utc
        Timecop.freeze(t) do
          miq_server.worker_heartbeat(pid)
          miq_server.validate_heartbeat(worker)
        end

        expect(worker.reload.last_heartbeat).to be_within(1.second).of(t)
      end
    end
  end
end
