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
end
