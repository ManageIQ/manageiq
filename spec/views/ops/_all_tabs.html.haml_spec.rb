require "spec_helper"

describe "ops/_analytics_details_tab.html.haml" do
  context "analytics tab selected" do
    before do
      assign(:sb, :active_tab => "analytics_details")
    end

    it "should render analytics detail page successfully" do
      render :partial => "ops/all_tabs",
             :locals  => {:x_active_tree => :analytics_tree,
                          :get_vmdb_config => {:product => {:analytics => true}}}
      expect(response).to render_template(:partial => "ops/_analytics_details_tab")
    end
  end
end
