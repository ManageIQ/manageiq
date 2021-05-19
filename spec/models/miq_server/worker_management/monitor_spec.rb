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
      server.setup_drb_variables
      server.worker_add(worker.pid)
    end

    it "destroys an unresponsive 'stopping' worker" do
      expect(Process).to receive(:kill).with("TERM", worker.pid)
      expect(Process).to receive(:kill).with(9, worker.pid)
      worker.update(:last_heartbeat => 20.minutes.ago)
      server.stop_worker(worker)
      server.check_not_responding
      server.reload
      expect(server.miq_workers).to be_empty
      expect { worker.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "monitors recently heartbeated 'stopping' workers" do
      expect(Process).to receive(:kill).with("TERM", worker.pid)
      worker.update(:last_heartbeat => 1.minute.ago)
      server.stop_worker(worker)
      server.check_not_responding
      server.reload
      expect(server.miq_workers.first.id).to eq(worker.id)
    end

    context "#sync_from_system" do
      context "#ensure_kube_monitors_started" do
        it "podified, ensures pod monitor started and orphaned rows are removed" do
          allow(server).to receive(:podified?).and_return(true)
          expect(server).to receive(:ensure_kube_monitors_started)
          expect(server).to receive(:cleanup_orphaned_worker_rows)
          server.sync_from_system
        end

        it "non-podified, orphaned rows are removed" do
          allow(server).to receive(:podified?).and_return(false)
          expect(server).to receive(:ensure_kube_monitors_started).never
          expect(server).to receive(:cleanup_orphaned_worker_rows)
          server.sync_from_system
        end
      end
    end

    context "#cleanup_orphaned_worker_rows" do
      context "podified" do
        let(:server2) { EvmSpecHelper.remote_miq_server }

        before do
          allow(server).to receive(:podified?).and_return(true)
          server.current_pods = {"1-generic-active" => {}}
        end

        after do
          server.current_pods.clear
        end

        it "removes this server's orphaned rows" do
          worker.update(:system_uid => "1-generic-orphan")
          FactoryBot.create(:miq_worker, :type => "MiqGenericWorker", :miq_server => server, :system_uid => "1-generic-active")
          server.cleanup_orphaned_worker_rows
          expect(MiqWorker.count).to eq(1)
        end

        it "skips orphaned rows for other servers" do
          worker.update(:miq_server => server2, :system_uid => "1-generic-orphan")
          FactoryBot.create(:miq_worker, :type => "MiqGenericWorker", :miq_server => server2, :system_uid => "1-generic-active")
          server.cleanup_orphaned_worker_rows
          expect(MiqWorker.count).to eq(2)
        end

        it "skips MiqCockpitWsWorker rows" do
          worker.update(:system_uid => "an_actual_guid", :type => "MiqCockpitWsWorker")
          server.cleanup_orphaned_worker_rows
          expect(MiqCockpitWsWorker.count).to eq(1)
        end
      end
    end

    context "#sync_workers" do
      let(:server) { EvmSpecHelper.local_miq_server }

      it "ensures only expected worker classes are constantized" do
        # Autoload abstract base class for the event catcher
        ManageIQ::Providers::BaseManager::EventCatcher

        # We'll try to constantize a non-existing EventCatcher class in an existing namespace,
        # which incorrectly resolves to the base manager event catcher.
        allow(MiqWorkerType).to receive(:worker_class_names).and_return(%w[ManageIQ::Providers::Foreman::ProvisioningManager::EventCatcher MiqGenericWorker])

        expect(ManageIQ::Providers::BaseManager::EventCatcher).not_to receive(:sync_workers)
        expect(MiqGenericWorker).to receive(:sync_workers).and_return(:adds => [111])
        expect(server.sync_workers).to eq("MiqGenericWorker"=>{:adds=>[111]})
      end

      it "rescues exceptions and moves on" do
        allow(MiqWorkerType).to receive(:worker_class_names).and_return(%w(MiqGenericWorker MiqPriorityWorker))
        allow(MiqGenericWorker).to receive(:sync_workers).and_raise
        expect(MiqPriorityWorker).to receive(:sync_workers).and_return(:adds => [123])
        expect(server.sync_workers).to eq("MiqPriorityWorker"=>{:adds=>[123]})
      end

      it "calls cleanup_failed_services" do
        allow(MiqWorkerType).to receive(:worker_class_names).and_return([])
        allow(MiqEnvironment::Command).to receive(:supports_systemd?).and_return(true)
        expect(server).to receive(:cleanup_failed_systemd_services)
        server.cleanup_failed_workers
      end
    end
  end
end
