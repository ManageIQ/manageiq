describe ManageIQ::Providers::StorageManager::CinderManager::RefreshWorker do
  describe ".ems_class" do
    it "is the parent manager" do
      expect(described_class.ems_class).to eq(ManageIQ::Providers::StorageManager::CinderManager)
    end
  end
end
