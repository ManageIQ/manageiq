require "spec_helper"
include ApplicationHelper

describe "layouts/listnav/_ems_cluster.html.haml" do
  before :each do
    set_controller_for_view("ems_cluster")
    assign(:panels, "ems_cluster_prop" => true, "ems_cluster_rel" => true)
    view.stub(:trunc_at).and_return(23)
    view.stub(:trunc_to).and_return(20)
    ActionView::Base.any_instance.stub(:role_allows).and_return(true)
  end

  it "both timeline links pass display=timeline" do
    record = EmsCluster.new(:name => "Test Cluster")
    assign(:record, record)
    record.stub(:has_events?).and_return(true)
    render
    response.should have_selector("a[title='Show Timelines'][href*='display=timeline']", :count => 1)
  end

  it "both template links pass display=miq_templates" do
    record = EmsCluster.new(:name => "Test Cluster")
    assign(:record, record)
    record.stub(:total_miq_templates).and_return(5)
    render
    response.should have_selector("a[title^='Show all Templates'][href*='display=miq_templates']", :count => 1)
  end
end
