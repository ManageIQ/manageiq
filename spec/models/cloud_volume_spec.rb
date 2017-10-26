describe CloudVolume do
  it ".available" do
    disk = FactoryGirl.create(:disk)
    FactoryGirl.create(:cloud_volume, :attachments => [disk])
    cv2 = FactoryGirl.create(:cloud_volume)

    expect(described_class.available).to eq([cv2])
  end
end
