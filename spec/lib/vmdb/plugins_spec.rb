describe Vmdb::Plugins do
  describe ".asset_paths" do
    it "with normal engines" do
      asset_paths = described_class.asset_paths

      asset_path = asset_paths.detect { |ap| ap.name == "ManageIQ::UI::Classic::Engine" }
      expect(asset_path.path).to eq ManageIQ::UI::Classic::Engine.root
      expect(asset_path.namespace).to eq "manageiq-ui-classic"
    end

    it "with engines with inflections" do
      asset_paths = described_class.asset_paths

      asset_path = asset_paths.detect { |ap| ap.name == "ManageIQ::V2V::Engine" }
      expect(asset_path.path).to eq ManageIQ::V2V::Engine.root
      expect(asset_path.namespace).to eq "manageiq-v2v"
    end
  end
end
