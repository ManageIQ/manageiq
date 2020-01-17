RSpec.describe CustomizationTemplateSysprep do
  context "#default_filename" do
    it "should be unattend.xml" do
      expect(described_class.new.default_filename).to eq('unattend.xml')
    end
  end
end
