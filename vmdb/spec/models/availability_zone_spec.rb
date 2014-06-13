require "spec_helper"

describe AvailabilityZone do
  it ".available" do
    FactoryGirl.create(:availability_zone_amazon)
    FactoryGirl.create(:availability_zone_openstack)
    FactoryGirl.create(:availability_zone_openstack_null)

    described_class.available.length.should == 2
    described_class.available.each { |az| az.class.should_not == AvailabilityZoneOpenstackNull }
  end
end
