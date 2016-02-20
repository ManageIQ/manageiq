include QuadiconHelper

describe "layouts/listnav/_ems_cluster.html.haml" do
  before :each do
    set_controller_for_view("ems_cluster")
    assign(:panels, "ems_cluster_prop" => true, "ems_cluster_rel" => true)
    allow(view).to receive(:truncate_length).and_return(23)
    allow(view).to receive(:role_allows).and_return(true)
  end

  it "both timeline links pass display=timeline" do
    record = EmsCluster.new(:name => "Test Cluster")
    assign(:record, record)
    allow(record).to receive(:has_events?).and_return(true)
    render
    expect(response).to have_selector("a[title='Show Timelines'][href*='display=timeline']", :count => 1)
  end

  it "both template links pass display=miq_templates" do
    record = EmsCluster.new(:name => "Test Cluster")
    assign(:record, record)
    allow(record).to receive(:total_miq_templates).and_return(5)
    render
    expect(response).to have_selector("a[title^='Show all Templates'][href*='display=miq_templates']", :count => 1)
  end
end
