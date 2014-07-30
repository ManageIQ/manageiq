require "spec_helper"

describe CloudVolume do
  it ".available" do
    disk = FactoryGirl.create(:disk)
    cv1 = FactoryGirl.create(:cloud_volume_amazon, :attachments => [disk])
    cv2 = FactoryGirl.create(:cloud_volume_amazon)

    described_class.available.should == [cv2]
  end
end
