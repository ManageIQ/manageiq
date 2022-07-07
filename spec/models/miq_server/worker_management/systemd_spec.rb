RSpec.describe MiqServer::WorkerManagement::Systemd do
  let(:units)           { [] }
  let(:server)          { EvmSpecHelper.local_miq_server }
  let(:systemd_manager) { double("DBus::Systemd::Manager") }

  before do
    MiqWorkerType.seed
    allow(MiqServer::WorkerManagement).to receive(:podified?).and_return(false)
    allow(MiqServer::WorkerManagement).to receive(:systemd?).and_return(true)
    allow(server.worker_manager).to receive(:systemd_manager).and_return(systemd_manager)
    allow(systemd_manager).to receive(:units).and_return(units)
  end

  context "#cleanup_failed_systemd_services" do
    before { server.worker_manager.sync_from_system }

    context "with no failed services" do
      let(:units) { [{:name => "manageiq-generic@68400a7e-1747-4f10-be2a-d0fc91b705ca.service", :description => "ManageIQ Generic Worker", :load_state => "loaded", :active_state => "active", :sub_state => "plugged", :job_id => 0, :job_type => "", :job_object_path => "/"}] }

      it "doesn't call DisableUnitFiles" do
        expect(systemd_manager).not_to receive(:DisableUnitFiles)
        server.worker_manager.cleanup_failed_systemd_services
      end
    end

    context "with failed services" do
      let(:service_name) { "manageiq-generic@68400a7e-1747-4f10-be2a-d0fc91b705ca.service" }
      let(:units) { [{:name => service_name, :description => "ManageIQ Generic Worker", :load_state => "loaded", :active_state => "failed", :sub_state => "plugged", :job_id => 0, :job_type => "", :job_object_path => "/"}] }

      it "calls DisableUnitFiles with the service name" do
        expect(systemd_manager).to receive(:StopUnit).with(service_name, "replace")
        expect(systemd_manager).to receive(:ResetFailedUnit).with(service_name)
        expect(systemd_manager).to receive(:DisableUnitFiles).with([service_name], false)

        server.worker_manager.cleanup_failed_systemd_services
      end
    end
  end

  context "#sync_from_system" do
    before { server.worker_manager.sync_from_system }

    let(:units) do
      [
        {:name => "manageiq-generic@68400a7e-1747-4f10-be2a-d0fc91b705ca.service", :active_state => "failed"},
        {:name => "manageiq-ui@cfe2c489-5c93-4b77-8620-cf6b1d3ec595.service",      :active_state => "active"},
        {:name => "ssh.service",                                                   :active_state => "active"}
      ]
    end

    it "filters out non-miq services" do
      expect(server.worker_manager.send(:miq_services).count).to eq(2)
    end
  end

  context "#failed_miq_services (private)" do
    before { server.worker_manager.sync_from_system }

    let(:units) do
      [
        {:name => "manageiq-generic@68400a7e-1747-4f10-be2a-d0fc91b705ca.service", :active_state => "failed"},
        {:name => "manageiq-ui@cfe2c489-5c93-4b77-8620-cf6b1d3ec595.service",      :active_state => "active"}
      ]
    end

    it "filters out only failed services" do
      expect(server.worker_manager.send(:failed_miq_services).count).to eq(1)
    end
  end

  context "#manageiq_service_base_names (private)" do
    it "returns the minimal_class_name" do
      expect(server.worker_manager.send(:manageiq_service_base_names)).to include("manageiq-generic", "manageiq-ui")
    end
  end

  context "#systemd_services (private)" do
    let(:units) do
      [
        {:name => "manageiq-generic@68400a7e-1747-4f10-be2a-d0fc91b705ca.service"},
        {:name => "manageiq-miq.slice"}
      ]
    end

    it "filters out non-service files" do
      expect(server.worker_manager.send(:systemd_services).count).to eq(1)
    end
  end

  context "#systemd_service_base_name (private)" do
    it "with a non-templated service" do
      expect(server.worker_manager.send(:systemd_service_base_name, :name => "miq.slice")).to eq("miq")
    end

    it "with a template service" do
      expect(server.worker_manager.send(:systemd_service_base_name, :name => "generic@.service")).to eq("generic")
    end

    it "with a templated service instance" do
      expect(server.worker_manager.send(:systemd_service_base_name, :name => "generic@68400a7e-1747-4f10-be2a-d0fc91b705ca.service")).to eq("generic")
    end
  end
end
