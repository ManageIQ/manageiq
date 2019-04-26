describe CloudVolume do
  it ".available" do
    disk = Disk.create
    FactoryBot.create(:cloud_volume, :attachments => [disk])
    cv2 = FactoryBot.create(:cloud_volume)

    expect(described_class.available).to eq([cv2])
  end
end
