require 'docker'
require_dependency 'embedded_ansible'

describe DockerEmbeddedAnsible do
  before do
    allow(Docker).to receive(:validate_version!).and_return(true)
    allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(false)
    allow(ContainerOrchestrator).to receive(:available?).and_return(false)
  end

  describe "subject" do
    it "is an instance of DockerEmbeddedAnsible" do
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe ".available?" do
    it "returns true when the docker gem is usable" do
      expect(described_class.available?).to be true
    end
  end

  describe "#alive?" do
    let(:connection) { double("APIConnection", :api => api) }
    let(:api)        { double("AnsibleAPI") }

    it "returns false if the api raises a JSON::ParserError" do
      expect(subject).to receive(:running?).and_return(true)
      expect(subject).to receive(:api_connection).and_return(connection)
      expect(api).to receive(:verify_credentials).and_raise(JSON::ParserError)

      expect(subject.alive?).to be false
    end
  end

  describe "#database_host (private)" do
    let(:my_server) { EvmSpecHelper.local_miq_server }
    let(:docker_network_settings) do
      settings = { "IPAM" => {"Config" => [{"Gateway" => "192.0.2.1"}]}}
      double("Docker::Network settings", :info => settings)
    end

    it "returns the active record database host when valid" do
      expect(subject).to receive(:database_configuration).and_return("host" => "db.example.com")
      expect(subject.send(:database_host)).to eq("db.example.com")
    end

    context "the database config doesn't list a host" do
      before do
        expect(subject).to receive(:database_configuration).and_return("dbname" => "testdatabase")
      end

      it "returns the server ip when set" do
        my_server.update_attributes(:ipaddress => "192.0.2.123")

        expect(subject.send(:database_host)).to eq("192.0.2.123")
      end

      it "returns the docker bridge gateway address when there is no server ip set" do
        my_server.update_attributes(:ipaddress => nil)

        expect(Docker::Network).to receive(:get).with("bridge").and_return(docker_network_settings)
        expect(subject.send(:database_host)).to eq("192.0.2.1")
      end
    end

    context "the datbase config containes 'host' => 'localhost'" do
      before do
        expect(subject).to receive(:database_configuration).and_return("host" => "localhost")
      end

      it "returns the server ip when set" do
        my_server.update_attributes(:ipaddress => "192.0.2.123")

        expect(subject.send(:database_host)).to eq("192.0.2.123")
      end

      it "returns the docker bridge gateway address when there is no server ip set" do
        my_server.update_attributes(:ipaddress => nil)

        expect(Docker::Network).to receive(:get).with("bridge").and_return(docker_network_settings)
        expect(subject.send(:database_host)).to eq("192.0.2.1")
      end
    end
  end
end
