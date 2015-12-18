require "spec_helper"

describe "miq_ae_customization/_dialog_resource.html.haml" do
  before do
    dt = FactoryGirl.create(:dialog_tab, :label => "tab01")
    assign(:record, dt)
  end

  it "correctly renders patternfly classes" do
    render :partial => "miq_ae_customization/dialog_resource",
           :locals  => {:curr_pos  => 0,
                        :obj       => {:id => 0},
                        :parent_id => 0,
                        :typ       => "Tab"}
    expect(response).to have_selector('div.panel.panel-default')
    expect(response).to have_selector('div.panel-heading')
    expect(response).to have_selector('h3.panel-title')
  end
end
