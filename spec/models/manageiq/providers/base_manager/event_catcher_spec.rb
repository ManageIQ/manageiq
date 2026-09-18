RSpec.describe ManageIQ::Providers::BaseManager::EventCatcher do
  let(:test_catcher) do
    stub_const("ManageIQ::Providers::TestCloud", Module.new)
    stub_const("ManageIQ::Providers::TestCloud::CloudManager", Class.new(ManageIQ::Providers::BaseManager) do
      def self.ems_type
        "test_cloud"
      end
    end)
    stub_const("ManageIQ::Providers::TestCloud::CloudManager::EventCatcher", Class.new(described_class))
    stub_const("ManageIQ::Providers::TestCloud::CloudManager::EventCatcher::Runner", Class.new(ManageIQ::Providers::BaseManager::EventCatcher::Runner))
    ManageIQ::Providers::TestCloud::CloudManager::EventCatcher
  end

  describe ".worker_settings_paths" do
    it "returns a path scoped to the provider's ems_type" do
      expect(test_catcher.worker_settings_paths).to eq([[:ems, :ems_test_cloud]])
    end
  end

  describe ".rails_worker?" do
    it "defaults to true when the setting is absent" do
      allow(test_catcher).to receive(:worker_settings).and_return({})
      expect(test_catcher.rails_worker?).to be(true)
    end

    it "returns true when the setting is explicitly true" do
      allow(test_catcher).to receive(:worker_settings).and_return(:rails_worker => true)
      expect(test_catcher.rails_worker?).to be(true)
    end

    it "returns false when the setting is explicitly false" do
      allow(test_catcher).to receive(:worker_settings).and_return(:rails_worker => false)
      expect(test_catcher.rails_worker?).to be(false)
    end
  end
end
