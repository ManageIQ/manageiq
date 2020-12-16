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

  describe "#container_image" do
    let(:generic_worker) { MiqGenericWorker.new }
    let(:ui_worker)      { MiqUiWorker.new }
    let(:api_worker)     { MiqWebServiceWorker.new }

    it "uses the BASE_WORKER_IMAGE value for a generic worker" do
      image_ref = "registry.example.com/manageiq/manageiq-test@sha256:2997e41a1195df90d8daf9714b619c9ae0c053f3d79e39bd8ed2d18b3c8da52a"
      stub_const("ENV", ENV.to_h.merge("BASE_WORKER_IMAGE" => image_ref))
      expect(generic_worker.container_image).to eq(image_ref)
    end

    it "uses the UI_WORKER_IMAGE value for a UI worker" do
      image_ref = "registry.example.com/manageiq/manageiq-ui-test@sha256:2997e41a1195df90d8daf9714b619c9ae0c053f3d79e39bd8ed2d18b3c8da52a"
      stub_const("ENV", ENV.to_h.merge("UI_WORKER_IMAGE" => image_ref))
      expect(ui_worker.container_image).to eq(image_ref)
    end

    it "uses the WEBSERVER_WORKER_IMAGE value for an API worker" do
      image_ref = "registry.example.com/manageiq/manageiq-web-test@sha256:2997e41a1195df90d8daf9714b619c9ae0c053f3d79e39bd8ed2d18b3c8da52a"
      stub_const("ENV", ENV.to_h.merge("WEBSERVER_WORKER_IMAGE" => image_ref))
      expect(api_worker.container_image).to eq(image_ref)
    end

    context "when CONTAINER_IMAGE_NAMESPACE is set" do
      before { stub_const("ENV", ENV.to_h.merge("CONTAINER_IMAGE_NAMESPACE" => "registry.example.com/manageiq")) }

      it "uses the correct default value" do
        expect(generic_worker.container_image).to eq("registry.example.com/manageiq/manageiq-base-worker:latest")
        expect(ui_worker.container_image).to eq("registry.example.com/manageiq/manageiq-ui-worker:latest")
        expect(api_worker.container_image).to eq("registry.example.com/manageiq/manageiq-webserver-worker:latest")
      end

      it "allows tag overrides" do
        stub_const("ENV", ENV.to_h.merge("CONTAINER_IMAGE_TAG" => "jansa-1"))
        expect(generic_worker.container_image).to eq("registry.example.com/manageiq/manageiq-base-worker:jansa-1")
        expect(ui_worker.container_image).to eq("registry.example.com/manageiq/manageiq-ui-worker:jansa-1")
        expect(api_worker.container_image).to eq("registry.example.com/manageiq/manageiq-webserver-worker:jansa-1")
      end
    end
  end

  describe "#resource_constraints" do
    context "when allowing resource constraints" do
      before { stub_settings(:server => {:worker_monitor => {:enforce_resource_constraints => true}}) }

      it "returns an empty hash when no thresholds are set" do
        allow(MiqGenericWorker).to receive(:worker_settings).and_return({})
        expect(MiqGenericWorker.new.resource_constraints).to eq({})
      end

      it "returns the correct hash when both values are set" do
        allow(MiqGenericWorker).to receive(:worker_settings).and_return(:memory_threshold => 500.megabytes, :cpu_threshold_percent => 50)
        constraints = {
          :limits => {
            :memory => "500Mi",
            :cpu    => "500m"
          }
        }
        expect(MiqGenericWorker.new.resource_constraints).to eq(constraints)
      end

      it "raises ArgumentError when request > limit" do
        allow(MiqGenericWorker).to receive(:worker_settings).and_return(:memory_request => 750.megabytes, :memory_threshold => 500.megabytes)
        expect { MiqGenericWorker.new.resource_constraints }.to raise_error(ArgumentError)
      end

      it "returns only memory when memory is set" do
        allow(MiqGenericWorker).to receive(:worker_settings).and_return(:memory_threshold => 500.megabytes)
        constraints = {
          :limits => {
            :memory => "500Mi",
          }
        }
        expect(MiqGenericWorker.new.resource_constraints).to eq(constraints)
      end

      it "returns only cpu when cpu is set" do
        allow(MiqGenericWorker).to receive(:worker_settings).and_return(:cpu_threshold_percent => 80)
        constraints = {
          :limits => {
            :cpu => "800m"
          }
        }
        expect(MiqGenericWorker.new.resource_constraints).to eq(constraints)
      end

      it "returns default cpu when it is set" do
        allow(MiqGenericWorker).to receive(:worker_settings).and_return(:cpu_request_percent => 10)
        constraints = {
          :requests => {
            :cpu => "100m"
          }
        }
        expect(MiqGenericWorker.new.resource_constraints).to eq(constraints)
      end

      it "returns default memory when it is set" do
        allow(MiqGenericWorker).to receive(:worker_settings).and_return(:memory_request => 250.megabytes)
        constraints = {
          :requests => {
            :memory => "250Mi",
          }
        }
        expect(MiqGenericWorker.new.resource_constraints).to eq(constraints)
      end

      it "returns memory pair when set" do
        allow(MiqGenericWorker).to receive(:worker_settings).and_return(:memory_request => 250.megabytes, :memory_threshold => 600.megabytes)
        constraints = {
          :requests => {
            :memory => "250Mi",
          },
          :limits         => {
            :memory => "600Mi",
          }
        }
        expect(MiqGenericWorker.new.resource_constraints).to eq(constraints)
      end
    end

    context "when not allowing resource constraints" do
      before { stub_settings(:server => {:worker_monitor => {:enforce_resource_constraints => false}}) }

      it "always returns an empty hash" do
        allow(MiqGenericWorker).to receive(:worker_settings).and_return(:memory_threshold => 500.megabytes, :cpu_threshold => 50)
        expect(MiqGenericWorker.new.resource_constraints).to eq({})
      end
    end
  end
end
