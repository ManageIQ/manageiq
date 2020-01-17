RSpec.describe PersistentVolumeClaim do
  describe "#storage_capacity" do
    let(:storage_size) { 123_456_789 }

    it "returns value for :storage key in Hash column :capacity" do
      persistent_volume = FactoryBot.create(
        :persistent_volume_claim,
        :capacity => {:storage => storage_size, :foo => "something"}
      )
      expect(persistent_volume.storage_capacity).to eq storage_size
    end

    it "returns nil if there is no :storage key in Hash column :capacity" do
      persistent_volume = FactoryBot.create(
        :persistent_volume_claim,
        :capacity => {:foo => "something"}
      )
      expect(persistent_volume.storage_capacity).to be nil
    end
  end
end
