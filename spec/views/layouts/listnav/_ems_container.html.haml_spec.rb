describe "layouts/listnav/_ems_container.html.haml" do
  helper(QuadiconHelper)

  before :each do
    set_controller_for_view("ems_container")
    assign(:panels, "ems_prop" => true, "ems_rel" => true)
    allow(view).to receive(:truncate_length).and_return(10)
    allow(view).to receive(:role_allows?).and_return(true)
  end

  it "link to Capacity & Utilization uses restful path" do
    @record = FactoryGirl.create(:ems_openshift)
    allow(@record).to receive(:has_perf_data?).and_return(true)
    render
    expect(response)
      .to include("Show Capacity &amp; Utilization\" href=\"/ems_container/#{@record.id}?display=performance\">")
  end
end
