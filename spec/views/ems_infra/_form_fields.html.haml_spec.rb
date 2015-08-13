require "spec_helper"

describe "rendering fields in ems_infra new/edit form" do
  before(:each) do
    @edit = {:new => {:emstype => "vm_ware"}}
  end

  it "displays Host Name" do
    render :partial => "ems_infra/form_fields", :locals => {:url => ""}
    expect(rendered).to match(/Hostname/)
  end

  it "doesn't display IP Address" do
    render :partial => "ems_infra/form_fields", :locals => {:url => ""}
    expect(rendered).not_to match(/\AIP\ Address/)
  end
end
