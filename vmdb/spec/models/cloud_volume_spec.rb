require "spec_helper"

describe CloudVolume do
  it ".available" do
    vm = FactoryGirl.create(:vm_amazon)
    cv1 = FactoryGirl.create(:cloud_volume_amazon, :vm => vm)
    cv2 = FactoryGirl.create(:cloud_volume_amazon)

    described_class.available.should == [cv2]
  end
end
