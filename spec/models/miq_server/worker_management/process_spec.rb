RSpec.describe MiqServer::WorkerManagement::Process do
  let(:server) { EvmSpecHelper.local_miq_server(:pid => 2) }

  before do
    MiqWorkerType.seed
    allow(MiqServer::WorkerManagement).to receive(:podified?).and_return(false)
    allow(MiqServer::WorkerManagement).to receive(:systemd?).and_return(false)
  end

  describe "#sync_from_system" do
    before do
      require "sys/proctable"
      allow(Sys::ProcTable).to receive(:ps).and_return(processes)
    end

    context "with no workers" do
      let(:processes) do
        [
          Struct::ProcTableStruct.new.tap do |proc|
            proc.cmdline = "postgres: 13/main: root vmdb_development [local] idle"
            proc.pid     = 1234
            proc.ppid    = 1
          end
        ]
      end

      it "filters out non-workers" do
        server.worker_manager.sync_from_system
        expect(server.worker_manager.send(:miq_processes)).to be_empty
      end
    end

    context "with a worker" do
      let(:processes) do
        [
          Struct::ProcTableStruct.new.tap do |proc|
            proc.cmdline = "postgres: 13/main: root vmdb_development [local] idle"
            proc.pid     = 1234
            proc.ppid    = 1
          end,
          Struct::ProcTableStruct.new.tap do |proc|
            proc.cmdline = "MIQ: Vmware::InfraManager::RefreshWorker id: 39, queue: ems_2"
            proc.pid     = 5678
            proc.ppid    = server.pid
          end
        ]
      end

      it "filters out non-workers" do
        server.worker_manager.sync_from_system
        expect(server.worker_manager.send(:miq_processes).count).to eq(1)
      end
    end
  end
end
