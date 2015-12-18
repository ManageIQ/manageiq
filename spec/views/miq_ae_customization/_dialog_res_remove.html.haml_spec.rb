require "spec_helper"

describe "miq_ae_customization/_dialog_res_remove.html.haml" do
  before do
    dt = FactoryGirl.create(:dialog_tab, :label => "tab01")
    assign(:record, dt)
  end

  it "correctly renders patternfly classes" do
    render :partial => "miq_ae_customization/dialog_res_remove",
           :locals  => {:curr_pos  => 0,
                        :obj       => {:id => 0},
                        :parent_id => 0,
                        :typ       => "Tab"}
    expect(response).to have_selector('a.fa.fa-close.pull-right')
  end
end
