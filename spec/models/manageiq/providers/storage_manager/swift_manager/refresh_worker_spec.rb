describe ManageIQ::Providers::StorageManager::SwiftManager::RefreshWorker do
  describe ".ems_class" do
    it "is the parent manager" do
      expect(described_class.ems_class).to eq(ManageIQ::Providers::StorageManager::SwiftManager)
    end
  end
end
