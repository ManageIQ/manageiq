require "spec_helper"

describe "layouts/_item.html.haml" do
  it "check if correct items are being rendered for filesystem" do
    set_controller_for_view("ems_infra")
    fs = FactoryGirl.create(:filesystem, :contents => "contents")
    assign(:view, FactoryGirl.create(:miq_report_filesystem))
    assign(:item, fs)
    assign(:lastaction, 'filesystems')
    render

    response.should have_selector('label', :text => 'Name')
    response.should have_selector('label', :text => 'File Name')
    response.should have_selector('label', :text => 'File Version')
    response.should have_selector('label', :text => 'Size')
    response.should have_selector('label', :text => 'Contents Available')
    response.should have_selector('label', :text => 'Permissions')
    response.should have_selector('label', :text => 'Collected On')
    response.should have_selector('label', :text => 'Contents')
    response.should have_selector('a', :text => 'Download')
  end
end
