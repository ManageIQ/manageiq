describe ManageIQ::Providers::Amazon::Regions do
  context "disable regions via Settings" do
    it "contains gov_cloud without it being disabled" do
      allow(Settings.ems.ems_amazon).to receive(:disabled_regions).and_return([])
      expect(described_class.names).to include("us-gov-west-1")
    end

    it "contains gov_cloud without disabled_regions being set at all - for backwards compatibility" do
      allow(Settings.ems).to receive(:ems_amazon).and_return(nil)
      expect(described_class.names).to include("us-gov-west-1")
    end

    it "does not contain some regions that are disabled" do
      allow(Settings.ems.ems_amazon).to receive(:disabled_regions).and_return(['us-gov-west-1'])
      expect(described_class.names).not_to include('us-gov-west-1')
    end
  end
end
