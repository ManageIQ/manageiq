require_dependency 'embedded_ansible'

describe ContainerEmbeddedAnsible do
  let(:miq_database) { MiqDatabase.first }

  before do
    allow(ContainerOrchestrator).to receive(:available?).and_return(true)

    FactoryGirl.create(:miq_region, :region => ApplicationRecord.my_region_number)
    MiqDatabase.seed
    EvmSpecHelper.create_guid_miq_server_zone
  end

  describe "subject" do
    it "is an instance of ContainerEmbeddedAnsible" do
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe ".available" do
    it "returns true" do
      expect(described_class.available?).to be true
    end
  end

  describe "#start" do
    around do |example|
      ENV["ANSIBLE_ADMIN_PASSWORD"] = "thepassword"
      example.run
      ENV.delete("ANSIBLE_ADMIN_PASSWORD")
    end

    it "sets the admin password using the environment variable and waits for the service to respond" do
      orch = double("ContainerOrchestrator")
      expect(ContainerOrchestrator).to receive(:new).and_return(orch)

      expect(orch).to receive(:scale).with("ansible", 1)
      expect(subject).to receive(:alive?).and_return(true)

      subject.start
      expect(miq_database.reload.ansible_admin_authentication.password).to eq("thepassword")
    end
  end

  describe "#stop" do
    it "scales the ansible pod to 0 replicas" do
      orch = double("ContainerOrchestrator")
      expect(ContainerOrchestrator).to receive(:new).and_return(orch)

      expect(orch).to receive(:scale).with("ansible", 0)

      subject.stop
    end
  end
end
