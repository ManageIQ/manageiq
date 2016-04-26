describe "catalog/_sandt_tree_show.html.haml" do
  before do
    set_controller_for_view("catalog")
    set_controller_for_view_to_be_nonrestful
    bundle = FactoryGirl.create(:service_template,
                                :name         => 'My Bundle',
                                :id           => 1,
                                :service_type => "composite",
                                :display      => true)
    assign(:record, bundle)
    assign(:sb, {})
  end

  it "Renders bundle summary screen" do
    render
    expect(rendered).to include('My Bundle')
  end
end
