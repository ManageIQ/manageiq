require "spec_helper"
include ApplicationHelper

describe "rendering quadicons of ext_management_system" do
  before(:each) do
    @settings = {:quadicons => {:ems => true}}
    @item = FactoryGirl.build(:ems_infra)
    @item.stub(:hosts).and_return(%w(foo bar))
    @item.stub(:image_name).and_return("foo")
    @layout = "ems_infra"
  end

  it "doesn't display IP Address in the tooltip" do
    render :partial => "layouts/quadicon/ext_management_system",
           :locals  => {:size => "72",
                        :typ  => "grid",
                        :item => @item}
    expect(rendered).not_to match(/IP Address/)
  end

  it "displays Host Name in the tooltip" do
    render :partial => "layouts/quadicon/ext_management_system",
           :locals  => {:size => "72",
                        :typ  => "grid",
                        :item => @item}
    expect(rendered).to match(/Hostname/)
  end

end
