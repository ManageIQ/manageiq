describe AvailabilityZone do
  it ".available" do
    FactoryGirl.create(:availability_zone_amazon)
    FactoryGirl.create(:availability_zone_openstack)
    FactoryGirl.create(:availability_zone_openstack_null)

    expect(described_class.available.length).to eq(2)
    described_class.available.each { |az| expect(az.class).not_to eq(ManageIQ::Providers::Openstack::CloudManager::AvailabilityZoneNull) }
  end

  it ".event_where_clause" do
    zone = FactoryGirl.create(:availability_zone_amazon)
    expect(zone.event_where_clause).not_to be nil
    expect(EmsEvent.where(zone.event_where_clause).length).to eq(0)
  end
end
