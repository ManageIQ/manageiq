RSpec.describe MiqWorker::ContainerCommon do
  before { EvmSpecHelper.local_miq_server }
  let(:compressed_server_id) { MiqServer.my_server.compressed_id }

  def deployment_name_for(name)
    "#{compressed_server_id}-#{name}"
  end

  describe "#configure_worker_deplyoment" do
    let(:test_deployment) do
      {
        :metadata => {
          :name      => "test",
          :labels    => {:app => "manageiq"},
          :namespace => "manageiq",
        },
        :spec     => {
          :selector => {:matchLabels => {:name => "test"}},
          :template => {
            :metadata => {:name => "test", :labels => {:name => "test", :app => "manageiq"}},
            :spec     => {
              :serviceAccountName => "miq-anyuid",
              :containers         => [{
                :name => "test",
                :env  => []
              }]
            }
          }
        }
      }
    end

    it "adds a node selector based on the zone name" do
      worker = FactoryBot.create(:miq_generic_worker)
      worker.configure_worker_deployment(test_deployment)

      expect(test_deployment.dig(:spec, :template, :spec, :nodeSelector)).to eq("manageiq/zone-#{MiqServer.my_zone}" => "true")
    end

    it "doesn't add a node selector for the default zone" do
      MiqServer.my_server.zone.update(:name => "default")
      worker = FactoryBot.create(:miq_generic_worker)
      worker.configure_worker_deployment(test_deployment)

      expect(test_deployment.dig(:spec, :template, :spec).keys).not_to include(:nodeSelector)
    end
  end

  describe "#worker_deployment_name" do
    let(:test_cases) do
      [
        {:subject => MiqGenericWorker.new, :name => deployment_name_for("generic")},
        {:subject => MiqUiWorker.new,      :name => deployment_name_for("ui")},
        {:subject => ManageIQ::Providers::Openshift::ContainerManager::EventCatcher.new(:queue_name => "ems_2"), :name => deployment_name_for("openshift-container-event-catcher-2")},
        {:subject => ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker.new, :name => deployment_name_for("redhat-infra-metrics-collector")}
      ]
    end

    it "returns the correct name for each worker" do
      test_cases.each { |test| expect(test[:subject].worker_deployment_name).to eq(test[:name]) }
    end

    it "no worker deployment names are over 60 characters" do
      # OpenShift does not allow deployment names over 63 characters
      # We also want to leave some for the ems_id so we compare against 60 to be safe
      MiqWorkerType.seed
      MiqWorkerType.pluck(:worker_type).each do |klass|
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

      expect(orchestrator).to receive(:scale).with(deployment_name_for("generic"), 2)
      MiqGenericWorker.new.scale_deployment
    end

    it "deletes the container objects if the worker count is zero" do
      allow(MiqGenericWorker).to receive(:worker_settings).and_return(:count => 0)

      expect(orchestrator).to receive(:scale).with(deployment_name_for("generic"), 0)
      worker = MiqGenericWorker.new
      expect(worker).to receive(:delete_container_objects)
      worker.scale_deployment
    end
  end
end
