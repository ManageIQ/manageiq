require "linux_admin"
require "awesome_spawn"

describe EmbeddedAnsible do
  describe ".new" do
    it "returns an instance of NullEmbeddedAnsible if there is no available subclass" do
      expect(MiqEnvironment::Command).to receive(:is_appliance?).and_return(false)
      expect(ContainerOrchestrator).to receive(:available?).and_return(false)

      expect(described_class.new).to be_an_instance_of(NullEmbeddedAnsible)
    end

    context "in an appliance" do
      before do
        allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(true)
      end

      it "returns an instance of ApplianceEmbeddedAnsible when the tower rpms are installed" do
        installed_rpms = {
          "ansible-tower-server" => "1.0.1",
          "ansible-tower-setup"  => "1.2.3",
          "vim"                  => "13.5.1"
        }
        expect(LinuxAdmin::Rpm).to receive(:list_installed).and_return(installed_rpms)

        expect(described_class.new).to be_an_instance_of(ApplianceEmbeddedAnsible)
      end
    end

    context "in Kubernetes/OpenShift" do
      it "returns an instance of ContainerEmbeddedAnsible" do
        expect(ContainerOrchestrator).to receive(:available?).and_return(true)
        expect(described_class.new).to be_an_instance_of(ContainerEmbeddedAnsible)
      end
    end
  end

  context ".available?" do
    context "in an appliance" do
      before do
        allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(true)
      end

      it "returns true when installed in the default location" do
        installed_rpms = {
          "ansible-tower-server" => "1.0.1",
          "ansible-tower-setup"  => "1.2.3",
          "vim"                  => "13.5.1"
        }
        expect(LinuxAdmin::Rpm).to receive(:list_installed).and_return(installed_rpms)

        expect(described_class.available?).to be_truthy
      end

      it "returns false when not installed" do
        expect(LinuxAdmin::Rpm).to receive(:list_installed).and_return("vim" => "13.5.1")

        expect(described_class.available?).to be_falsey
      end
    end

    it "returns true unconditionally in a container" do
      allow(MiqEnvironment::Command).to receive(:is_container?).and_return(true)
      expect(described_class.available?).to be_truthy
    end

    it "returns false outside of an appliance" do
      allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(false)
      expect(described_class.available?).to be_falsey
    end
  end

  describe ".running?" do
    it "always returns true when in a container" do
      expect(MiqEnvironment::Command).to receive(:is_container?).and_return(true)
      expect(LinuxAdmin::Service).not_to receive(:new)

      expect(described_class.running?).to be_truthy
    end
  end

  context "with an miq_databases row" do
    let(:miq_database) { MiqDatabase.first }
    let(:extra_vars) do
      {
        :minimum_var_space  => 0,
        :http_port          => described_class::HTTP_PORT,
        :https_port         => described_class::HTTPS_PORT,
        :tower_package_name => "ansible-tower-server"
      }.to_json
    end

    before do
      FactoryGirl.create(:miq_region, :region => ApplicationRecord.my_region_number)
      MiqDatabase.seed
      EvmSpecHelper.create_guid_miq_server_zone
    end

    describe ".api_connection" do
      around do |example|
        ENV["ANSIBLE_SERVICE_HOST"] = "192.0.2.1"
        ENV["ANSIBLE_SERVICE_PORT_HTTP"] = "1234"
        example.run
        ENV.delete("ANSIBLE_SERVICE_HOST")
        ENV.delete("ANSIBLE_SERVICE_PORT_HTTP")
      end

      it "connects to the ansible service when running in a container" do
        miq_database.set_ansible_admin_authentication(:password => "adminpassword")
        expect(MiqEnvironment::Command).to receive(:is_container?).and_return(true)

        expect(AnsibleTowerClient::Connection).to receive(:new).with(
          :base_url   => "http://192.0.2.1:1234/api/v1",
          :username   => "admin",
          :password   => "adminpassword",
          :verify_ssl => 0
        )

        described_class.api_connection
      end
    end

    describe ".alive?" do
      it "returns false if the service is not configured" do
        expect(described_class).to receive(:configured?).and_return false
        expect(described_class.alive?).to be false
      end

      it "returns false if the service is not running" do
        expect(described_class).to receive(:configured?).and_return true
        expect(described_class).to receive(:running?).and_return false
        expect(described_class.alive?).to be false
      end

      context "when a connection is attempted" do
        let(:api_conn) { double("AnsibleAPIConnection") }
        let(:api) { double("AnsibleAPIResource") }

        before do
          expect(described_class).to receive(:configured?).and_return true
          expect(described_class).to receive(:running?).and_return true

          miq_database.set_ansible_admin_authentication(:password => "adminpassword")

          expect(AnsibleTowerClient::Connection).to receive(:new).with(
            :base_url   => "http://localhost:54321/api/v1",
            :username   => "admin",
            :password   => "adminpassword",
            :verify_ssl => 0
          ).and_return(api_conn)
          expect(api_conn).to receive(:api).and_return(api)
        end

        it "returns false when a AnsibleTowerClient::ConnectionError is raised" do
          error = AnsibleTowerClient::ConnectionError.new("error")
          expect(api).to receive(:verify_credentials).and_raise(error)
          expect(described_class.alive?).to be false
        end

        it "returns false when a AnsibleTowerClient::SSLError is raised" do
          error = AnsibleTowerClient::SSLError.new("error")
          expect(api).to receive(:verify_credentials).and_raise(error)
          expect(described_class.alive?).to be false
        end

        it "returns false when an AnsibleTowerClient::ConnectionError is raised" do
          expect(api).to receive(:verify_credentials).and_raise(AnsibleTowerClient::ConnectionError)
          expect(described_class.alive?).to be false
        end

        it "returns false when an AnsibleTowerClient::ClientError is raised" do
          expect(api).to receive(:verify_credentials).and_raise(AnsibleTowerClient::ClientError)
          expect(described_class.alive?).to be false
        end

        it "raises when other errors are raised" do
          expect(api).to receive(:verify_credentials).and_raise(RuntimeError)
          expect { described_class.alive? }.to raise_error(RuntimeError)
        end

        it "returns true when no error is raised" do
          expect(api).to receive(:verify_credentials)
          expect(described_class.alive?).to be true
        end
      end
    end

    describe ".configured?" do
      it "returns true when the file doesn't exist and we are running in a container" do
        expect(MiqEnvironment::Command).to receive(:is_container?).and_return(true)
        expect(described_class.configured?).to be true
      end
    end

    context "when in a container" do
      before do
        expect(MiqEnvironment::Command).to receive(:is_container?).and_return(true)
      end

      describe ".stop" do
        it "scales the ansible pod to 0 replicas" do
          orch = double("ContainerOrchestrator")
          expect(ContainerOrchestrator).to receive(:new).and_return(orch)

          expect(orch).to receive(:scale).with("ansible", 0)

          described_class.stop
        end
      end

      describe ".disable" do
        it "scales the ansible pod to 0 replicas" do
          orch = double("ContainerOrchestrator")
          expect(ContainerOrchestrator).to receive(:new).and_return(orch)

          expect(orch).to receive(:scale).with("ansible", 0)

          described_class.disable
        end
      end

      describe ".start" do
        around do |example|
          ENV["ANSIBLE_ADMIN_PASSWORD"] = "thepassword"
          example.run
          ENV.delete("ANSIBLE_ADMIN_PASSWORD")
        end

        it "sets the admin password using the environment variable and waits for the service to respond" do
          orch = double("ContainerOrchestrator")
          expect(ContainerOrchestrator).to receive(:new).and_return(orch)

          expect(orch).to receive(:scale).with("ansible", 1)
          expect(described_class).to receive(:alive?).and_return(true)

          described_class.start
          expect(miq_database.reload.ansible_admin_authentication.password).to eq("thepassword")
        end
      end
    end
  end
end
