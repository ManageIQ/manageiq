require "spec_helper"
include ApplicationHelper

describe "rendering fields in host new/edit form" do
  before(:each) do
    set_controller_for_view("host")
    @host = FactoryGirl.create(:host)
    @edit = {:new => @host}
  end

  it "displays Host Name" do
    render :partial => "host/form"
    expect(rendered).to match(/Host\ Name/)
  end

  it "doesn't display IP Address" do
    render :partial => "host/form"
    expect(rendered).not_to match(/\AIP\ Address/)
  end
end
