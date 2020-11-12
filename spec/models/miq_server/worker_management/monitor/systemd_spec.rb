RSpec.describe MiqServer::WorkerManagement::Monitor::Systemd do
  let(:units)           { [] }
  let(:server)          { EvmSpecHelper.create_guid_miq_server_zone.second }
  let(:systemd_manager) { double("DBus::Systemd::Manager") }

  before do
    MiqWorkerType.seed
    allow(server).to receive(:systemd_manager).and_return(systemd_manager)
    allow(systemd_manager).to receive(:units).and_return(units)
  end

  context "#cleanup_failed_systemd_services" do
    context "with no failed services" do
      let(:units) { [{:name => "generic@68400a7e-1747-4f10-be2a-d0fc91b705ca.service", :description => "ManageIQ Generic Worker", :load_state => "loaded", :active_state => "active", :sub_state => "plugged", :job_id => 0, :job_type => "", :job_object_path => "/"}] }

      it "doesn't call DisableUnitFiles" do
        expect(systemd_manager).not_to receive(:DisableUnitFiles)
        server.cleanup_failed_systemd_services
      end
    end

    context "with failed services" do
      let(:service_name) { "generic@68400a7e-1747-4f10-be2a-d0fc91b705ca.service" }
      let(:units) { [{:name => service_name, :description => "ManageIQ Generic Worker", :load_state => "loaded", :active_state => "failed", :sub_state => "plugged", :job_id => 0, :job_type => "", :job_object_path => "/"}] }

      it "calls DisableUnitFiles with the service name" do
        expect(systemd_manager).to receive(:StopUnit).with(service_name, "replace")
        expect(systemd_manager).to receive(:ResetFailedUnit).with(service_name)
        expect(systemd_manager).to receive(:DisableUnitFiles).with([service_name], false)

        server.cleanup_failed_systemd_services
      end
    end
  end

  context "#systemd_all_miq_services" do
    let(:units) do
      [
        {:name => "generic@68400a7e-1747-4f10-be2a-d0fc91b705ca.service", :active_state => "failed"},
        {:name => "ui@cfe2c489-5c93-4b77-8620-cf6b1d3ec595.service",      :active_state => "active"},
        {:name => "ssh.service",                                          :active_state => "active"}
      ]
    end

    it "filters out non-miq services" do
      expect(server.systemd_all_miq_services.count).to eq(2)
    end
  end

  context "#systemd_failed_miq_services" do
    let(:units) do
      [
        {:name => "generic@68400a7e-1747-4f10-be2a-d0fc91b705ca.service", :active_state => "failed"},
        {:name => "ui@cfe2c489-5c93-4b77-8620-cf6b1d3ec595.service",      :active_state => "active"}
      ]
    end

    it "filters out only failed services" do
      expect(server.systemd_failed_miq_services.count).to eq(1)
    end
  end

  context "#systemd_miq_service_base_names (private)" do
    it "returns the minimal_class_name" do
      expect(server.send(:systemd_miq_service_base_names)).to include("generic", "ui")
    end
  end

  context "#systemd_services (private)" do
    let(:units) do
      [
        {:name => "generic@68400a7e-1747-4f10-be2a-d0fc91b705ca.service"},
        {:name => "miq.slice"}
      ]
    end

    it "filters out non-service files" do
      expect(server.send(:systemd_services).count).to eq(1)
    end
  end

  context "#systemd_service_base_name (private)" do
    it "with a non-templated service" do
      expect(server.send(:systemd_service_base_name, :name => "miq.slice")).to eq("miq")
    end

    it "with a template service" do
      expect(server.send(:systemd_service_base_name, :name => "generic@.service")).to eq("generic")
    end

    it "with a templated service instance" do
      expect(server.send(:systemd_service_base_name, :name => "generic@68400a7e-1747-4f10-be2a-d0fc91b705ca.service")).to eq("generic")
    end
  end
end
