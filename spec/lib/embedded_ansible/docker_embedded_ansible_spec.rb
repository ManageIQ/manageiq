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
end
