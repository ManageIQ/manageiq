RSpec.describe ManageIQ::Providers::BaseManager::EventCatcher do
  describe ".worker_settings_paths" do
    it "returns a path scoped to the provider's ems_type" do
      fake_manager = double(:ems_type => "test_cloud")
      allow(described_class).to receive(:module_parent).and_return(fake_manager)
      expect(described_class.worker_settings_paths).to eq([[:ems, :ems_test_cloud]])
    end
  end

  describe ".rails_worker?" do
    it "defaults to true when the setting is absent" do
      allow(described_class).to receive(:worker_settings).and_return({})
      expect(described_class.rails_worker?).to be(true)
    end

    it "returns true when the setting is explicitly true" do
      allow(described_class).to receive(:worker_settings).and_return(:rails_worker => true)
      expect(described_class.rails_worker?).to be(true)
    end

    it "returns false when the setting is explicitly false" do
      allow(described_class).to receive(:worker_settings).and_return(:rails_worker => false)
      expect(described_class.rails_worker?).to be(false)
    end
  end
end
