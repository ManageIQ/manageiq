require "spec_helper"

describe "rendering fields in ems_cloud new/edit form" do
  before(:each) do
    @edit = {:new => {:emstype => "openstack"}, :amazon_regions => {}}
  end

  it "displays Host Name" do
    render :partial => "ems_cloud/form_fields", :locals => {:url => ""}
    expect(rendered).to match(/Hostname/)
  end

  it "doesn't display IP Address" do
    render :partial => "ems_cloud/form_fields", :locals => {:url => ""}
    expect(rendered).not_to match(/IP\ Address/)
  end
end
