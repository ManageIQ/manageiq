describe "layouts/listnav/_persistent_volume.html.haml" do
  helper(QuadiconHelper)

  before :each do
    set_controller_for_view("persistent_volume")
    assign(:panels, "ems_prop" => true, "ems_rel" => true)
    allow(view).to receive(:truncate_length).and_return(10)
    allow(view).to receive(:role_allows?).and_return(true)
  end

  let(:provider) do
    allow_any_instance_of(User).to receive(:get_timezone).and_return(Time.zone)
    FactoryGirl.create(:ems_openshift)
  end

  it "link to parent containers provider uses restful path" do
    @record = FactoryGirl.create(:persistent_volume, :parent => provider)
    render
    expect(response).to include("Show this persistent volume&#39;s parent Containers Provider\" href=\"/ems_container/#{@record.parent.id}\">")
  end
end
