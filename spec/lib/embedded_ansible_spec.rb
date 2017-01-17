require "linux_admin"
require "awesome_spawn"

describe EmbeddedAnsible do
  before do
    ENV["APPLIANCE_ANSIBLE_DIRECTORY"] = nil
  end

  context ".available?" do
    it "returns true when installed in the default location" do
      allow(Dir).to receive(:exist?).with("/opt/ansible-installer").and_return(true)

      expect(described_class.available?).to be_truthy
    end

    it "returns true when installed in the custom location in env var" do
      ENV["APPLIANCE_ANSIBLE_DIRECTORY"] = "/tmp"
      allow(Dir).to receive(:exist?).with("/tmp").and_return(true)
      allow(Dir).to receive(:exist?).with("/opt/ansible-installer").and_return(false)

      expect(described_class.available?).to be_truthy
    end

    it "returns false when not installed" do
      allow(Dir).to receive(:exist?).with("/opt/ansible-installer").and_return(false)

      expect(described_class.available?).to be_falsey
    end
  end

  context "with services" do
    let(:nginx_service)       { double("nginx service") }
    let(:supervisord_service) { double("supervisord service") }
    let(:rabbitmq_service)    { double("rabbitmq service") }

    before do
      expect(AwesomeSpawn).to receive(:run!)
        .with("source /etc/sysconfig/ansible-tower; echo $TOWER_SERVICES")
        .and_return(double(:output => "nginx supervisord rabbitmq"))
      allow(LinuxAdmin::Service).to receive(:new).with("nginx").and_return(nginx_service)
      allow(LinuxAdmin::Service).to receive(:new).with("supervisord").and_return(supervisord_service)
      allow(LinuxAdmin::Service).to receive(:new).with("rabbitmq").and_return(rabbitmq_service)
    end

    describe ".running?" do
      it "returns true when all services are running" do
        expect(nginx_service).to receive(:running?).and_return(true)
        expect(supervisord_service).to receive(:running?).and_return(true)
        expect(rabbitmq_service).to receive(:running?).and_return(true)

        expect(described_class.running?).to be true
      end

      it "returns false when a service is not running" do
        expect(nginx_service).to receive(:running?).and_return(true)
        expect(supervisord_service).to receive(:running?).and_return(false)

        expect(described_class.running?).to be false
      end
    end

    describe ".stop" do
      it "stops all the services" do
        expect(nginx_service).to receive(:stop).and_return(nginx_service)
        expect(supervisord_service).to receive(:stop).and_return(supervisord_service)
        expect(rabbitmq_service).to receive(:stop).and_return(rabbitmq_service)

        expect(nginx_service).to receive(:disable).and_return(nginx_service)
        expect(supervisord_service).to receive(:disable).and_return(supervisord_service)
        expect(rabbitmq_service).to receive(:disable).and_return(rabbitmq_service)

        described_class.stop
      end
    end
  end
end
