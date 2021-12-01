RSpec.describe AvailabilityZone do
  it ".available" do
    FactoryBot.create(:availability_zone_amazon)
    FactoryBot.create(:availability_zone_openstack)
    FactoryBot.create(:availability_zone_openstack_null)

    expect(described_class.available.length).to eq(2)
    described_class.available.each { |az| expect(az.class).not_to eq(ManageIQ::Providers::Openstack::CloudManager::AvailabilityZoneNull) }
  end
end
