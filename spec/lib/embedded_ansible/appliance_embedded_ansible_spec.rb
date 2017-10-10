require_dependency 'embedded_ansible'

describe ApplianceEmbeddedAnsible do
  before do
    allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(true)
    allow(ContainerOrchestrator).to receive(:available?).and_return(false)

    installed_rpms = {
      "ansible-tower-server" => "1.0.1",
      "ansible-tower-setup"  => "1.2.3",
      "vim"                  => "13.5.1"
    }
    allow(LinuxAdmin::Rpm).to receive(:list_installed).and_return(installed_rpms)
  end

  describe "subject" do
    it "is an instance of ApplianceEmbeddedAnsible" do
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe ".available?" do
    it "returns true with the tower rpms installed" do
      expect(described_class.available?).to be true
    end
  end
end
