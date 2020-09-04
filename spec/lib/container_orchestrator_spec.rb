RSpec.describe ContainerOrchestrator do
  let(:kube_apps_connection) { subject.send(:kube_apps_connection) }
  let(:kube_connection)      { subject.send(:kube_connection) }
  let(:cert)                 { Tempfile.new("cert") }
  let(:token)                { Tempfile.new("token") }
  let(:namespace_file)       { Tempfile.new("namespace") }
  let(:cert_path)            { cert.path }
  let(:token_path)           { token.path }
  let(:namespace_path)       { namespace_file.path }
  let(:kube_host)            { "kube.example.com" }
  let(:kube_port)            { "8443" }
  let(:namespace)            { "manageiq" }

  before do
    stub_const("ContainerOrchestrator::CA_CERT_FILE", cert_path)
    stub_const("ContainerOrchestrator::TOKEN_FILE", token_path)
    stub_const("ContainerOrchestrator::ObjectDefinition::NAMESPACE_FILE", namespace_path)
    ENV["KUBERNETES_SERVICE_HOST"] = kube_host
    ENV["KUBERNETES_SERVICE_PORT"] = kube_port
    File.write(namespace_path, namespace)
  end

  after do
    FileUtils.rm_f(cert_path)
    FileUtils.rm_f(token_path)
    FileUtils.rm_f(namespace_path)
    ENV.delete("KUBERNETES_SERVICE_HOST")
    ENV.delete("KUBERNETES_SERVICE_PORT")
  end

  describe ".available" do
    it "returns false when the required files are not present" do
      FileUtils.rm_f(cert_path)
      FileUtils.rm_f(token_path)
      expect(described_class.available?).to be false
    end

    it "returns true when the files are present" do
      expect(described_class.available?).to be true
    end
  end

  describe "#kube_connection (private)" do
    it "connects to the correct uri" do
      expect(kube_connection.api_endpoint.to_s).to eq("https://kube.example.com:8443/api")
      expect(kube_connection.auth_options[:bearer_token_file]).to eq(token_path)
      expect(kube_connection.ssl_options[:verify_ssl]).to eq(1)
    end
  end

  describe "#kube_apps_connection (private)" do
    it "connects to the correct uri" do
      expect(kube_apps_connection.api_endpoint.to_s).to eq("https://kube.example.com:8443/apis/apps")
      expect(kube_apps_connection.auth_options[:bearer_token_file]).to eq(token_path)
      expect(kube_apps_connection.ssl_options[:verify_ssl]).to eq(1)
    end
  end

  describe "#default_environment (private)" do
    it "doesn't include messaging env vars when MESSAGING_TYPE is not set" do
      env = subject.send(:default_environment)
      expect(env).not_to include(hash_including(:name => "MESSAGING_TYPE"))
      expect(env).not_to include(hash_including(:name => "MESSAGING_PORT"))
      expect(env).not_to include(hash_including(:name => "MESSAGING_HOSTNAME"))
      expect(env).not_to include(hash_including(:name => "MESSAGING_PASSWORD"))
      expect(env).not_to include(hash_including(:name => "MESSAGING_USERNAME"))
    end

    context "when MESSAGING_TYPE is set" do
      before { stub_const("ENV", ENV.to_h.merge("MESSAGING_TYPE" => "kafka", "MESSAGING_PORT" => "9092")) }

      it "sets the messaging env vars" do
        expect(subject.send(:default_environment)).to include(
          {:name => "MESSAGING_PORT", :value => "9092"},
          {:name => "MESSAGING_TYPE", :value => "kafka"},
          {:name      => "MESSAGING_HOSTNAME",
           :valueFrom => {:secretKeyRef=>{:name => "kafka-secrets", :key => "hostname"}}},
          {:name      => "MESSAGING_PASSWORD",
           :valueFrom => {:secretKeyRef=>{:name => "kafka-secrets", :key => "password"}}},
          {:name      => "MESSAGING_USERNAME",
           :valueFrom => {:secretKeyRef=>{:name => "kafka-secrets", :key => "username"}}}
        )
      end
    end
  end

  context "with stub connections" do
    let(:apps_connection_stub) { double("AppsConnection") }
    let(:kube_connection_stub) { double("KubeConnection") }

    before do
      allow(subject).to receive(:kube_apps_connection).and_return(apps_connection_stub)
      allow(subject).to receive(:kube_connection).and_return(kube_connection_stub)
    end

    describe "#scale" do
      it "patches the deployment with the specified number of replicas" do
        deployment_patch = {:spec => {:replicas => 4}}
        expect(apps_connection_stub).to receive(:patch_deployment).with("deployment", deployment_patch, namespace)

        subject.scale("deployment", 4)
      end
    end

    describe "#create_deployment" do
      it "creates a deployment with the given name and edits" do
        expect(apps_connection_stub).to receive(:create_deployment) do |definition|
          expect(definition[:metadata][:name]).to eq("test")
          expect(definition[:metadata][:namespace]).to eq("manageiq")

          expect(definition[:spec][:template][:spec][:serviceAccountName]).to eq("test-account")

          expect(definition[:spec][:template][:spec][:containers].first[:image]).to eq("test-image")
        end

        subject.create_deployment("test") do |spec|
          spec[:spec][:template][:spec][:serviceAccountName] = "test-account"

          spec[:spec][:template][:spec][:containers].first[:image] = "test-image"
        end
      end

      it "doesn't raise an exception for an existing object" do
        error = KubeException.new(500, "deployment config already exists", "")
        expect(apps_connection_stub).to receive(:create_deployment).and_raise(error)

        expect { subject.create_deployment("test") }.not_to raise_error
      end
    end

    describe "#create_service" do
      it "creates a service with the given name, port, and edits" do
        expect(kube_connection_stub).to receive(:create_service) do |definition|
          expect(definition[:metadata][:name]).to eq("http")
          expect(definition[:metadata][:namespace]).to eq("manageiq")

          ports = definition[:spec][:ports]
          expect(ports.first).to eq(:name => "http-80", :port => 80, :targetPort => 80)
          expect(ports.last).to eq(:name => "https", :port => 443, :targetPort => 5000)

          expect(definition[:spec][:selector][:service]).to eq("http")
        end

        subject.create_service("http", {:service => "http"}, 80) do |spec|
          spec[:spec][:ports] << {:name => "https", :port => 443, :targetPort => 5000}
        end
      end

      it "doesn't raise an exception for an existing object" do
        error = KubeException.new(500, "service already exists", "")
        expect(kube_connection_stub).to receive(:create_service).and_raise(error)

        expect { subject.create_service("http", {:service => "http"}, 80) }.not_to raise_error
      end
    end

    describe "#create_secret" do
      it "creates a secret with the given name and data" do
        expect(kube_connection_stub).to receive(:create_secret) do |definition|
          expect(definition[:metadata][:name]).to eq("mysecret")
          expect(definition[:metadata][:namespace]).to eq("manageiq")

          expect(definition[:stringData]).to eq(
            "secret-one" => "very_secret",
            "secret-two" => "super_secret"
          )
        end

        subject.create_secret("mysecret", "secret-one" => "very_secret") do |spec|
          spec[:stringData]["secret-two"] = "super_secret"
        end
      end

      it "doesn't raise an exception for an existing object" do
        error = KubeException.new(500, "secret mysecret already exists", "")
        expect(kube_connection_stub).to receive(:create_secret).and_raise(error)

        expect { subject.create_secret("mysecret", {}) }.not_to raise_error
      end
    end

    describe "#delete_deployment" do
      it "deletes the replication controller if it exists" do
        expect(apps_connection_stub).to receive(:delete_deployment).with("deploy_name", "manageiq")
        expect(subject).to receive(:scale).with("deploy_name", 0)

        subject.delete_deployment("deploy_name")
      end
    end

    describe "initial pods and updates" do
      let(:orchestrator_pod_name) { "orchestrator-9f99d8cb9" }
      let(:app_name) { "manageiq" }

      before do
        allow(subject).to receive(:app_name).and_return(app_name)
        allow(subject).to receive(:pod_name).and_return(orchestrator_pod_name)
      end

      describe "#get_pods" do
        it "sets namespace and label_selector" do
          expect(subject).to receive(:app_name).and_return("manageiq")
          expect(kube_connection_stub).to receive(:get_pods).with(hash_including(:namespace => namespace, :label_selector => "app=#{app_name},#{app_name}-orchestrated-by=#{orchestrator_pod_name}"))
          subject.get_pods
        end
      end

      describe "#watch_pods" do
        it "sets namespace and label_selector" do
          expect(kube_connection_stub).to receive(:watch_pods).with(hash_including(:namespace => namespace, :resource_version => 0, :label_selector => "app=#{app_name},#{app_name}-orchestrated-by=#{orchestrator_pod_name}")).and_return([])
          subject.watch_pods(0)
        end

        it "defaults resource_version" do
          expect(kube_connection_stub).to receive(:watch_pods).with(hash_including(:resource_version => nil)).and_return([])
          subject.watch_pods
        end

        it "accepts provided resource_version" do
          expect(kube_connection_stub).to receive(:watch_pods).with(hash_including(:resource_version => 100)).and_return([])
          subject.watch_pods(100)
        end
      end
    end
  end
end
