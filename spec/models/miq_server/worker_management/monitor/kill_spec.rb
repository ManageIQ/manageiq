RSpec.describe MiqServer::WorkerManagement::Monitor::Kill do
  context "#kill_all_workers" do
    let(:server)   { EvmSpecHelper.create_guid_miq_server_zone.second }
    let(:is_local) { true }
    let(:worker)   do
      FactoryBot.create(:miq_generic_worker, :pid => 1234, :status => MiqWorker::STATUS_STARTING, :miq_server => server).tap do |w|
        MiqWorker.where(:id => w.id).update_all(:type => "NonExistingClass")
      end
    end

    before do
      server.setup_drb_variables
      server.worker_add(worker.pid)
      allow(server).to receive(:is_local?).and_return(is_local)
    end

    def assert_worker_record_deleted_and_not_monitored
      expect(MiqWorker.count).to eq(0)
      expect(server.reload.miq_workers.count).to eq(0)
      expect(server.instance_variable_get(:@workers).keys.length).to eq(0)
    end

    context "local" do
      it "stopped worker is removed" do
        MiqWorker.all.update_all(:status => MiqWorker::STATUS_STOPPED)
        expect(Process).to_not receive(:kill)

        server.kill_all_workers

        assert_worker_record_deleted_and_not_monitored
      end

      it "started worker is killed and removed" do
        MiqWorker.all.update_all(:status => MiqWorker::STATUS_STARTED)
        expect(Process).to receive(:kill).with(9, worker.pid)

        server.kill_all_workers

        assert_worker_record_deleted_and_not_monitored
      end
    end

    context "remote" do
      let(:is_local) { false }

      it "starting worker untouched" do
        expect(Process).to_not receive(:kill)

        server.kill_all_workers

        expect(MiqWorker.count).to eq(1)
        expect(server.reload.miq_workers.count).to eq(1)
        expect(server.instance_variable_get(:@workers).keys).to eq([worker.pid])
      end
    end
  end
end
