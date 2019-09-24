describe ContainerOrchestrator do
  let(:connection)      { subject.send(:connection) }
  let(:kube_connection) { subject.send(:kube_connection) }
  let(:cert)            { Tempfile.new("cert") }
  let(:token)           { Tempfile.new("token") }
  let(:cert_path)       { cert.path }
  let(:token_path)      { token.path }
  let(:kube_host)       { "kube.example.com" }
  let(:kube_port)       { "8443" }
  let(:namespace)       { "manageiq" }

  before do
    stub_const("ContainerOrchestrator::CA_CERT_FILE", cert_path)
    stub_const("ContainerOrchestrator::TOKEN_FILE", token_path)
    ENV["KUBERNETES_SERVICE_HOST"] = kube_host
    ENV["KUBERNETES_SERVICE_PORT"] = kube_port
    ENV["MY_POD_NAMESPACE"] = namespace
  end

  after do
    FileUtils.rm_f(cert_path)
    FileUtils.rm_f(token_path)
    ENV.delete("KUBERNETES_SERVICE_HOST")
    ENV.delete("KUBERNETES_SERVICE_PORT")
    ENV.delete("MY_POD_NAMESPACE")
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

  describe "#connection (private)" do
    it "connects to the correct uri" do
      expect(connection.api_endpoint.to_s).to eq("https://kube.example.com:8443/oapi")
      expect(connection.auth_options[:bearer_token_file]).to eq(token_path)
      expect(connection.ssl_options[:verify_ssl]).to eq(1)
    end
  end

  describe "#kube_connection (private)" do
    it "connects to the correct uri" do
      expect(kube_connection.api_endpoint.to_s).to eq("https://kube.example.com:8443/api")
      expect(kube_connection.auth_options[:bearer_token_file]).to eq(token_path)
      expect(kube_connection.ssl_options[:verify_ssl]).to eq(1)
    end
  end

  context "with stub connections" do
    let(:connection_stub)      { double("OpenShiftConnection") }
    let(:kube_connection_stub) { double("KubeConnection") }

    before do
      allow(subject).to receive(:connection).and_return(connection_stub)
      allow(subject).to receive(:kube_connection).and_return(kube_connection_stub)
    end

    describe "#scale" do
      it "patches the deployment config with the specified number of replicas" do
        deployment_patch = {:spec => {:replicas => 4}}
        expect(connection_stub).to receive(:patch_deployment_config).with("deployment", deployment_patch, namespace)

        subject.scale("deployment", 4)
      end
    end

    describe "#create_deployment_config" do
      it "creates a deployment config with the given name and edits" do
        expect(connection_stub).to receive(:create_deployment_config) do |definition|
          expect(definition[:metadata][:name]).to eq("test")
          expect(definition[:metadata][:namespace]).to eq("manageiq")

          expect(definition[:spec][:template][:spec][:serviceAccount]).to eq("test-account")
          expect(definition[:spec][:template][:spec][:serviceAccountName]).to eq("test-account")

          expect(definition[:spec][:template][:spec][:containers].first[:image]).to eq("test-image")
        end

        subject.create_deployment_config("test") do |spec|
          spec[:spec][:template][:spec][:serviceAccount] = "test-account"
          spec[:spec][:template][:spec][:serviceAccountName] = "test-account"

          spec[:spec][:template][:spec][:containers].first[:image] = "test-image"
        end
      end

      it "doesn't raise an exception for an existing object" do
        error = KubeException.new(500, "deployment config already exists", "")
        expect(connection_stub).to receive(:create_deployment_config).and_raise(error)

        expect { subject.create_deployment_config("test") }.not_to raise_error
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
        end

        subject.create_service("http", 80) do |spec|
          spec[:spec][:ports] << {:name => "https", :port => 443, :targetPort => 5000}
        end
      end

      it "doesn't raise an exception for an existing object" do
        error = KubeException.new(500, "service already exists", "")
        expect(kube_connection_stub).to receive(:create_service).and_raise(error)

        expect { subject.create_service("http", 80) }.not_to raise_error
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

    describe "#delete_deployment_config" do
      it "deletes the replication controller if it exists" do
        rc = double("ReplicationController", :metadata => double(:name => "rc_name"))

        expect(kube_connection_stub).to receive(:get_replication_controllers)
          .with(:label_selector => "openshift.io/deployment-config.name=dc_name", :namespace => "manageiq")
          .and_return([rc])

        expect(connection_stub).to receive(:delete_deployment_config).with("dc_name", "manageiq")
        expect(kube_connection_stub).to receive(:delete_replication_controller).with("rc_name", "manageiq")
        expect(subject).to receive(:scale).with("dc_name", 0)

        subject.delete_deployment_config("dc_name")
      end

      it "doesn't try to delete the replication controler if it doesn't exist" do
        expect(kube_connection_stub).to receive(:get_replication_controllers)
          .with(:label_selector => "openshift.io/deployment-config.name=dc_name", :namespace => "manageiq")
          .and_return([])

        expect(connection_stub).to receive(:delete_deployment_config).with("dc_name", "manageiq")
        expect(kube_connection_stub).not_to receive(:delete_replication_controller)
        expect(subject).to receive(:scale).with("dc_name", 0)

        subject.delete_deployment_config("dc_name")
      end
    end
  end
end
