require "spec_helper"
include ApplicationHelper

describe "layouts/listnav/_cloud_tenant.html.haml" do
  before :each do
    set_controller_for_view("cloud_tenant")
    assign(:panels, "ems_prop" => true, "ems_rel" => true)
    view.stub(:truncate_length).and_return(10)
    ActionView::Base.any_instance.stub(:role_allows).and_return(true)
  end

  let(:provider) do
    allow_any_instance_of(User).to receive(:get_timezone).and_return(Time.zone)
    FactoryGirl.create(:ems_openstack)
  end

  it "link to parent cloud provider uses restful path" do
    @record = FactoryGirl.create(:cloud_tenant,  :ext_management_system => provider)
    render
    expect(response).to include("Show this Cloud Tenant&#39;s parent Cloud Provider\" href=\"/ems_cloud/#{@record.ext_management_system.id}\">")
  end
end