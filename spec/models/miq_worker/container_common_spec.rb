describe MiqWorker::ContainerCommon do
  describe "#worker_deployment_name" do
    let(:test_cases) do
      [
        {:subject => MiqGenericWorker.new, :name => "generic"},
        {:subject => MiqUiWorker.new,      :name => "ui"},
        {:subject => ManageIQ::Providers::Openshift::ContainerManager::EventCatcher.new(:queue_name => "ems_2"), :name => "openshift-container-event-catcher-2"},
        {:subject => ManageIQ::Providers::Redhat::NetworkManager::MetricsCollectorWorker.new, :name => "redhat-network-metrics-collector"}
      ]
    end

    it "returns the correct name for each worker" do
      test_cases.each { |test| expect(test[:subject].worker_deployment_name).to eq(test[:name]) }
    end

    it "no worker deployment names are over 60 characters" do
      # OpenShift does not allow deployment names over 63 characters
      # We also want to leave some for the ems_id so we compare against 60 to be safe
      MIQ_WORKER_TYPES_IN_KILL_ORDER.each do |klass|
        expect(klass.constantize.new.worker_deployment_name.length).to be <= 60
      end
    end
  end

  describe "#scale_deployment" do
    let(:orchestrator) { double("ContainerOrchestrator") }

    before do
      allow(ContainerOrchestrator).to receive(:new).and_return(orchestrator)
    end

    it "scales the deployment to the number of configured workers" do
      allow(MiqGenericWorker).to receive(:worker_settings).and_return(:count => 2)

      expect(orchestrator).to receive(:scale).with("generic", 2)
      MiqGenericWorker.new.scale_deployment
    end

    it "deletes the container objects if the worker count is zero" do
      allow(MiqGenericWorker).to receive(:worker_settings).and_return(:count => 0)

      expect(orchestrator).to receive(:scale).with("generic", 0)
      worker = MiqGenericWorker.new
      expect(worker).to receive(:delete_container_objects)
      worker.scale_deployment
    end
  end
end
