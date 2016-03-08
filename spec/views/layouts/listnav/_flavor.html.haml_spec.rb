include QuadiconHelper

describe "layouts/listnav/_flavor.html.haml" do
  before :each do
    set_controller_for_view("flavor")
    assign(:panels, "ems_prop" => true, "ems_rel" => true)
    allow(view).to receive(:truncate_length).and_return(10)
    allow(view).to receive(:role_allows).and_return(true)
  end

  let(:provider) do
    allow_any_instance_of(User).to receive(:get_timezone).and_return(Time.zone)
    FactoryGirl.create(:ems_openstack)
  end

  it "link to parent cloud provider uses restful path" do
    @record = FactoryGirl.create(:flavor_openstack, :ext_management_system => provider, :name => "A test")
    render
    expect(response).to include("Show this Flavor&#39;s parent Cloud Provider\" href=\"/ems_cloud/#{@record.ext_management_system.id}\">")
  end
end
