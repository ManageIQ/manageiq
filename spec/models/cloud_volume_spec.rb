describe CloudVolume do
  it ".available" do
    disk = FactoryGirl.create(:disk)
    FactoryGirl.create(:cloud_volume, :attachments => [disk])
    cv2 = FactoryGirl.create(:cloud_volume)

    expect(described_class.available).to eq([cv2])
  end

  describe "#generic_custom_buttons" do
    before do
      allow(CustomButton).to receive(:buttons_for).with("CloudVolume").and_return("this is a list of custom buttons")
    end

    it "returns all the custom buttons for cloud volumes" do
      expect(CloudVolume.new.generic_custom_buttons).to eq("this is a list of custom buttons")
    end
  end
end
