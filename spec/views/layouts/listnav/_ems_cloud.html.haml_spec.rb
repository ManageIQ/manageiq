include QuadiconHelper

describe "layouts/listnav/_ems_cloud.html.haml" do
  before :each do
    set_controller_for_view("ems_cloud")
    assign(:panels, "ems_cloud_prop" => true, "ems_cloud_rel" => true)
    allow(view).to receive(:truncate_length).and_return(23)
    allow(view).to receive(:role_allows).and_return(true)
  end

  it "Flavors link for Openstack cloud manager uses restful path" do
    record = FactoryGirl.create(:ems_openstack)
    assign(:record, record)
    allow(record).to receive(:flavors).and_return(5)
    render
    expect(response).to include "ems_cloud/#{record.id}?display=flavors"
  end

  it "Flavors link for Amazon cloud manager uses restful paths" do
    record = ManageIQ::Providers::Amazon::CloudManager.new(:name => "Test Cloud")
    assign(:record, record)
    allow(record).to receive(:flavors).and_return(14)
    render
    expect(response).to include "ems_cloud?display=flavors"
  end
  it "Availability Zones link uses restful paths" do
    record = FactoryGirl.create(:ems_openstack)
    assign(:record, record)
    allow(record).to receive(:availability_zones).and_return(14)
    render
    expect(response).to include "ems_cloud/#{record.id}?display=availability_zones"
  end
  it "Cloud Tenants link uses restful paths" do
    record = ManageIQ::Providers::Amazon::CloudManager.new(:name => "Test Cloud")
    assign(:record, record)
    allow(record).to receive(:cloud_tenants).and_return(10)
    render
    expect(response).to include "ems_cloud?display=cloud_tenants"
  end
end
