require "spec_helper"

describe AvailabilityZone do
  it ".available" do
    FactoryGirl.create(:availability_zone_amazon)
    FactoryGirl.create(:availability_zone_openstack)
    FactoryGirl.create(:availability_zone_openstack_null)

    described_class.available.length.should == 2
    described_class.available.each { |az| az.class.should_not == ManageIQ::Providers::Openstack::CloudManager::AvailabilityZoneNull }
  end

  it ".event_where_clause" do
    zone = FactoryGirl.create(:availability_zone_amazon)
    zone.event_where_clause.should_not be nil
    EmsEvent.where(zone.event_where_clause).length.should be == 0
  end
end
