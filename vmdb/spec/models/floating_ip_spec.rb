require "spec_helper"

describe FloatingIp do
  it ".available" do
    vm = FactoryGirl.create(:vm_amazon)
    ip1 = FactoryGirl.create(:floating_ip_amazon, :vm => vm)
    ip2 = FactoryGirl.create(:floating_ip_amazon)

    described_class.available.should == [ip2]
  end
end
