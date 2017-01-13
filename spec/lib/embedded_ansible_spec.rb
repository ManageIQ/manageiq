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
end
