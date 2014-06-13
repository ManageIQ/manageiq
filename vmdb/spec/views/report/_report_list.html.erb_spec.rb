require "spec_helper"
include ApplicationHelper

describe "report/_report_list.html.erb" do
  before do
    rep_details = {
                    "rep 5" => {"id" => 5},
                    "rep 6" => {"id" => 6},
                    "rep 7" => {"id" => 7},
                    "rep 8" => {"id" => 8}
                  }
    #setup Array of Array with 2 level Folders and reports
    rpt_menu =  [
                  ["Folder 1",[["Folder1-1",["rep 1","rep 2"]]]],
                  ["Folder 2",[["Folder2-1",["rep 5","rep 6"]],
                               ["Folder2-2",["rep 7","rep 8"]]]]
                ]
    assign(:sb, {
                  :active_accord => :reports,
                  :active_tree => :reports_tree,
                  :rep_details => rep_details,
                  :rpt_menu => rpt_menu,
                  :trees => {:reports_tree => {:active_node => "xx-1_xx-1-0"}}
                }
          )
  end

  it "Check links in the list view" do
    render
    response.should have_selector("//tr[@onclick=\"cfmeDynatree_activateNode('reports_tree','xx-1_xx-1-0_rep-5');\"]")
    response.should have_selector("//tr[@onclick=\"cfmeDynatree_activateNode('reports_tree','xx-1_xx-1-0_rep-6');\"]")
  end
end
