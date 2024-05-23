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
      before do
        stub_const("ENV", ENV.to_h.merge(
                            "MESSAGING_TYPE"           => "kafka",
                            "MESSAGING_PORT"           => "9092",
                            "MESSAGING_SSL_CA"         => "/etc/pki/ca-trust/source/anchors/root.crt",
                            "MESSAGING_SASL_MECHANISM" => "PLAIN",
                            "MESSAGING_HOSTNAME"       => "hostname",
                            "MESSAGING_PASSWORD"       => "password",
                            "MESSAGING_USERNAME"       => "username"
                          ))
      end

      it "sets the messaging env vars" do
        expect(subject.send(:default_environment)).to include(
          {:name => "MESSAGING_PORT", :value => "9092"},
          {:name => "MESSAGING_TYPE", :value => "kafka"},
          {:name => "MESSAGING_SSL_CA", :value => "/etc/pki/ca-trust/source/anchors/root.crt"},
          {:name => "MESSAGING_SASL_MECHANISM", :value => "PLAIN"},
          {:name => "MESSAGING_HOSTNAME", :value => "hostname"},
          {:name => "MESSAGING_PASSWORD", :value => "password"},
          {:name => "MESSAGING_USERNAME", :value => "username"}
        )
      end
    end

    it "sets database environment variables" do
      stub_const("ENV", ENV.to_h.merge(
        "DATABASE_NAME"     => "vmdb_production",
        "DATABASE_SSL_MODE" => "verify-full"
      ))

      expect(subject.send(:default_environment)).to include({:name => "DATABASE_SSL_MODE", :value => "verify-full"})
      expect(subject.send(:default_environment)).not_to include({:name => "DATABASE_NAME", :valueFrom => {:secretKeyRef => {:key => "dbname", :name => "postgresql-secrets"}}})
    end

    it "sets APPLICATION_DOMAIN" do
      stub_const("ENV", ENV.to_h.merge("APPLICATION_DOMAIN" => "manageiq"))
      expect(subject.send(:default_environment)).to include({:name => "APPLICATION_DOMAIN", :value => "manageiq"})
    end

    it "doesn't include memcached env vars by default" do
      env = subject.send(:default_environment)

      expect(env).not_to include(hash_including(:name => "MEMCACHED_ENABLE_SSL"))
      expect(env).not_to include(hash_including(:name => "MEMCACHED_SSL_CA"))
    end

    context "when MESSAGING_TYPE is set" do
      before { stub_const("ENV", ENV.to_h.merge("MEMCACHED_ENABLE_SSL" => "true", "MEMCACHED_SSL_CA" => "/etc/pki/ca-trust/source/anchors/root.crt")) }

      it "sets the messaging env vars" do
        expect(subject.send(:default_environment)).to include(
          {:name => "MEMCACHED_ENABLE_SSL", :value => "true"},
          {:name => "MEMCACHED_SSL_CA",     :value => "/etc/pki/ca-trust/source/anchors/root.crt"}
        )
      end
    end
  end

  context "#deployment_definition (private)" do
    let(:container_orchestrator) { ContainerOrchestrator.new }
    before do
      allow(ContainerOrchestrator).to receive(:new).and_return(container_orchestrator)
      expect(container_orchestrator).to receive(:my_node_affinity_arch_values).and_return(["amd64", "arm64"])
    end

    it "skips the database root certificate if the orchestrator doesn't have it" do
      expect(File).to receive(:file?).with("/.postgresql/root.crt").and_return(false)
      allow(File).to receive(:file?).and_call_original # allow other calls to .file? to still work

      deployment_definition = subject.send(:deployment_definition, "test")

      expect(deployment_definition.fetch_path(:spec, :template, :spec, :containers, 0, :volumeMounts).length).to eq(3)
      expect(deployment_definition.fetch_path(:spec, :template, :spec, :volumes).length).to eq(3)
    end

    it "mounts the database root certificate" do
      expect(File).to receive(:file?).with("/.postgresql/root.crt").and_return(true)
      allow(File).to receive(:file?).and_call_original

      deployment_definition = subject.send(:deployment_definition, "test")

      expect(deployment_definition.fetch_path(:spec, :template, :spec, :containers, 0, :volumeMounts)).to include({
        :mountPath => "/.postgresql",
        :name      => "pg-root-certificate",
        :readOnly  => true
      })
      expect(deployment_definition.fetch_path(:spec, :template, :spec, :volumes)).to include({
        :name   => "pg-root-certificate",
        :secret => {
          :secretName => "postgresql-secrets",
          :items      => [
            :key  => "rootcertificate",
            :path => "root.crt",
          ],
        }
      })
    end

    it "mounts the root CA certificate" do
      stub_const("ENV", ENV.to_h.merge("SSL_SECRET_NAME" => "some-secret-name"))

      deployment_definition = subject.send(:deployment_definition, "test")

      expect(deployment_definition.fetch_path(:spec, :template, :spec, :containers, 0, :volumeMounts)).to include({
        :mountPath => "/etc/pki/ca-trust/source/anchors",
        :name      => "internal-root-certificate",
        :readOnly  => true
      })
      expect(deployment_definition.fetch_path(:spec, :template, :spec, :volumes)).to include({
        :name   => "internal-root-certificate",
        :secret => {
          :secretName => "some-secret-name",
          :items      => [
            :key  => "root_crt",
            :path => "root.crt",
          ],
        }
      })
    end

    it "includes node affinities" do
      deployment_definition = subject.send(:deployment_definition, "test")

      expect(deployment_definition.fetch_path(:spec, :template, :spec, :affinity, :nodeAffinity, :requiredDuringSchedulingIgnoredDuringExecution, :nodeSelectorTerms, 0, :matchExpressions, 0)).to include({
        :key => "kubernetes.io/arch",
        :operator => "In",
        :values => ["amd64", "arm64"],
      })
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
      let(:container_orchestrator) { ContainerOrchestrator.new }
      before do
        allow(ContainerOrchestrator).to receive(:new).and_return(container_orchestrator)
        expect(container_orchestrator).to receive(:my_node_affinity_arch_values).and_return(["amd64", "arm64"])
      end

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

      it "#get_pod_by_namespace_and_hostname" do
        pods = [
          double("pod", :metadata => double("pod-metadata", :name => "3r1-ui-abcdef123-xyz12")),
          double("pod", :metadata => double("pod-metadata", :name => "3r1-api-bcdefa123-yza12")),
          double("pod", :metadata => double("pod-metadata", :name => "orchestrator-cdefab1234-zab12"))
        ]
        expect(kube_connection_stub).to receive(:get_pods).with(:namespace => namespace).and_return(pods)

        expect(subject.get_pod_by_namespace_and_hostname(namespace, "3r1-ui-abcdef123-xyz12")).to eq pods.first
      end

      it "#my_pod" do
        stub_const("ENV", ENV.to_h.merge("HOSTNAME" => "orchestrator-cdefab1234-zab12"))
        pods = [
          double("pod", :metadata => double("pod-metadata", :name => "3r1-ui-abcdef123-xyz12")),
          double("pod", :metadata => double("pod-metadata", :name => "3r1-api-bcdefa123-yza12")),
          double("pod", :metadata => double("pod-metadata", :name => "orchestrator-cdefab1234-zab12"))
        ]
        expect(kube_connection_stub).to receive(:get_pods).with(:namespace => namespace).and_return(pods)
        orchestrator_pod = pods.last

        expect(subject.my_pod).to eq orchestrator_pod
      end
    end
  end
end
