require "spec_helper"

describe ManageIQ::Providers::Openstack::CloudManager::CloudVolume do
  let(:ems) { FactoryGirl.create(:ems_openstack) }
  let(:zone) { FactoryGirl.create(:availability_zone_openstack,
                                  :ext_management_system => ems) }
  let(:aggregate_without_zone) do
    FactoryGirl.create(:host_aggregate_openstack,
                       :ext_management_system => ems)
  end

  let(:aggregate_without_created_zone) do
    FactoryGirl.create(:host_aggregate_openstack,
                       :ext_management_system => ems,
                       :availability_zone     => "nonzone")
  end

  let(:aggregate_with_zone) do
    FactoryGirl.create(:host_aggregate_openstack,
                       :ext_management_system => ems,
                       :availability_zone     => zone.ems_ref)
  end

  it "handles availability zone" do
    expect(aggregate_without_zone.availability_zone_obj).to be_nil
    expect(aggregate_without_created_zone.availability_zone_obj).to be_nil
    expect(aggregate_with_zone.availability_zone_obj).to eq(zone)
  end
end
