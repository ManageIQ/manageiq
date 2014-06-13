require "spec_helper"
include ApplicationHelper

describe "configuration/_ui_2.html.erb" do
  before(:each) do
    views = {:tagging=>:grid, :compare=>:expanded, :compare_mode=>:details, :drift=>:expanded, :drift_mode=>:details,
             :dashboards=>:textual, :treesize=>:"20", :vmitem=>:list}
    edit =  {
        :new => {:views => views}
    }
    view.instance_variable_set(:@edit, edit)
    ActionView::Base.any_instance.stub(:role_allows).and_return(true)
  end
  it "should display VDI box" do
    view.stub(:get_vmdb_config).and_return(:product => {:vdi => true})
    render
    response.should have_selector("fieldset p.legend", :text => 'VDI')
  end

  it "should not display VDI box" do
    view.stub(:get_vmdb_config).and_return(:product => {:vdi => false})
    render
    response.should_not have_selector("fieldset p.legend", :text => 'VDI')
  end
end
