RSpec.describe CustomizationTemplateCloudInit do
  context "#default_filename" do
    it "should be user-data.txt" do
      expect(described_class.new.default_filename).to eq('user-data.txt')
    end
  end
end
